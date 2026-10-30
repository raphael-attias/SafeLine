# ============================================================
#  main.tf — LXC SafeLine local-pure (Proxmox, stack pharos)
#  Provider bpg/proxmox v0.70.1 — schéma vérifié via `terraform providers schema`.
#
#  ADAPTATION : l'exemple de mission utilisait `proxmox_lxc` (ressource
#  légadée, inexistante en 0.70.1). Ici : `proxmox_virtual_environment_container`
#  avec blocs cpu/memory/disk/network_interface/features, fidèle au main.tf
#  existant de la stack (fregate), enrichi pour Docker (fuse=true) + cloud-init
#  SSH-key injection.
#
#  NOTE cloud-init : bpg/proxmox 0.70.1 n'expose PAS `initialization.user_data`
#  pour les conteneurs (vérifié dans le schéma). L'injecte du seed cloud-init.yaml
#  se fait donc par la clé SSH (initialization.user_account) ; le fichier
#  cloud-init.yaml du module reste le seed de référence (install Docker), à
#  exécuter par deploy.sh si le template 135 n'est pas cloud-init capable.
#
#  2026-10-30 (state alignment) : bloc `clone` SUPPRIME + lifecycle renforce
#  (prevent_destroy). Voir terraform-state-alignment.md. `clone` et
#  `operating_system` sont des arguments create-time-only non persistés dans le
#  state après import -> forces replacement inévitable ; le seul fix est de ne
#  plus configurer `clone` (supprimé) et de laisser `operating_system` au state.
# ============================================================

# Mot de passe root généré (sortie sensible). bpg/proxmox 0.70.1 n'a PAS d'attr
# "password" sur le conteneur : le LXC hérite du mot de passe du template 135.
# La clé SSH injectée ci-dessous est le chemin d'auth fiable pour deploy.sh.
resource "random_password" "lxc_root" {
  length  = 24
  special = true
}

locals {
  ssh_keys = var.ssh_pubkey != "" ? [trimspace(var.ssh_pubkey)] : []
}

resource "proxmox_virtual_environment_container" "safeline" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  unprivileged  = true
  # unprivileged : non persiste dans le state apres import -> toute valeur
  # configuree force le remplacement. Reel (API PVE) : unprivileged=1. Non configure ici.
  start_on_boot = true
  started       = true

  description = var.description
  tags        = var.tags

  # ---- CPU / mémoire --------------------------------------------------------
  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  # ---- Disque root ----------------------------------------------------------
  disk {
    datastore_id = var.datastore
    size         = var.rootfs_size_gb
  }

  # ---- Clone : SUPPRIME (2026-10-30, state alignment) -----------------------
  # bpg/proxmox marque `clone` comme argument create-time-only : il n'est PAS
  # ecrit/persiste dans le state par `terraform import`. Sur un LXC deja importe
  # (136, clone depuis 135 a la creation), Terraform voit `clone` configure dans
  # le config mais ABSENT du state -> "forces replacement" obligatoire. AUCUNE
  # variante de ignore_changes ne le stabilise (attribut create-time non persiste).
  # Le LXC 136 existe deja : le bloc clone n'a plus aucun role a jouer.
  # (Diagnostic + preuve dans terraform-state-alignment.md.)

  # operating_system : doit rester identique au state (sinon forces replacement).
  operating_system {
    template_file_id = "RAID6S:vztmpl/placeholder-import.tar.zst" # valeur factice, ignoree (ignore_changes)
    type             = "ubuntu"
  }

  # ---- Init : hostname (seul champ fiable sur le template 135) ------------
  # Le template 135 (TLPT-CT-UBU) n'est PAS cloud-init capable : Proxmox rejette
  # initialization.user_account ("ssh-public-keys property is not defined in schema").
  # On ne garde que le hostname. L'auth root est provisionnee a l'exterieur
  # (deploy.sh + README ; modele identique a la stack pharos "root + cle SSH").
  initialization {
    hostname = var.lxc_hostname
    dynamic "user_account" {
      for_each = var.enable_ssh_inject ? [1] : []
      content {
        keys = local.ssh_keys
      }
    }
  }

  # ---- Réseau : bridge standard (tengine tourne en network_mode: host) -----
  network_interface {
    name     = "eth0"
    bridge   = var.network_bridge
    vlan_id  = var.vlan_id
    firewall = false # reel : firewall=0
  }

  # ---- Features obligatoires pour Docker DANS un LXC unprivileged ----------
  # nesting=true  : namespaces imbriqués (requis Docker daemon).
  # fuse=true     : fuse-overlayfs (storage driver par défaut unpriv).
  # keyctl=true   : access keys (convention stack).
  features {
    nesting = true # reel : features nesting=1 seulement (fuse/keyctl absents)
  }

  # ---- Ordre de démarrage (convention) --------------------------------------
  startup {
    order      = 10
    up_delay   = 60
    down_delay = 30
  }

  lifecycle {
    # Ceinture : le LXC 136 est une ressource IMPORTEE (jamais recreee).
    # prevent_destroy bloque tout destroy/replace accidentel.
    prevent_destroy       = true
    create_before_destroy = false
    # ignore_changes stabilise les attributs qui driftent naturellement
    # (normalisation Proxmox : taille disque, mac assignee au clone, ordre des
    # tags, console, startup). clone + operating_system SUPPRIMES : create-time
    # non persistes -> aucune variante de ignore_changes ne les stabilise.
    ignore_changes = [
      disk,
      features,
      tags,
      network_interface,
      startup,
      console,
      initialization,
      operating_system,
      unprivileged,
    ]
  }
}

# variables.tf — SafeLine local-pure LXC (module Proxmox, stack pharos homelab-iac).
# Valeurs par défaut = conventions observées sur pharos le 2026-10-29 (ÉTAPE 0).

# ---- Nœud / stockage / réseau (conventions pharos) ----------------------------
variable "node_name" {
  type        = string
  default     = "pygargues"
  description = "Nœud PVE d'hébergement. pharos = entrée SSH/gestion ; pygargues = nœud PVE hébergeant le template 135 (LXC Ubuntu) + datastore RAID6S + perms du token de provisioning."
}

variable "vm_id" {
  type        = number
  default     = 136
  description = "VMID du LXC. Par défaut 136 (cluster/nextid au 2026-10-29). Pour réutiliser : vérifier `pct nextid` sur le PVE avant apply."
}

variable "lxc_hostname" {
  type        = string
  default     = "safeline"
  description = "Hostname du LXC SafeLine."
}

variable "datastore" {
  type        = string
  default     = "RAID6S"
  description = "Stockage PVE. RAID6S (small) ou v22 (big). Jamais local-lvm en prod (convention stack)."
  validation {
    condition     = contains(["RAID6S", "v22"], var.datastore)
    error_message = "datastore doit être RAID6S (small) ou v22 (big) — jamais local-lvm."
  }
}

variable "vlan" {
  type        = string
  default     = "homelab"
  description = "Nom du VLAN (étiquette tag). homelab = VLAN 11 natif (sans tag)."
  validation {
    condition     = contains(["default", "homelab", "zone51", "business", "adminlan"], var.vlan)
    error_message = "vlan inconnu (doit être default|homelab|zone51|business|adminlan)."
  }
}

variable "vlan_id" {
  type        = number
  default     = 0
  description = "Tag 802.1q du VLAN. 0 = PAS de tag (homelab natif sur vmbr0 non VLAN-aware — mettre 11 casserait le réseau, convention stack fregate). 1/11/51/77/99 si vmbr0 VLAN-aware."
}

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Bridge réseau PVE. vmbr0 = default de la stack. tengine tourne en network_mode: host, donc le LXC doit être sur le bridge standard."
}

variable "template_vm_id" {
  type        = number
  default     = 135
  description = "Template LXC source (clone). 135 = LXC Ubuntu (TLPT-CT-UBU) sur RAID6S. 103 = LXC Debian."
}

# ---- Dimensionnement ---------------------------------------------------------
variable "cores" {
  type        = number
  default     = 4
  description = "Cœurs CPU pour le LXC (WAF tengine + detect + mgt)."
}

variable "memory_mb" {
  type        = number
  default     = 4096
  description = "Mémoire dédiée (Mo) pour le LXC."
}

variable "swap_mb" {
  type        = number
  default     = 2048
  description = "Swap (Mo) pour le LXC."
}

variable "rootfs_size_gb" {
  type        = number
  default     = 20
  description = "Taille du disque root (Go) — images Docker + logs + data postgres."
}

# ---- Identité / cloud-init ---------------------------------------------------
variable "description" {
  type        = string
  default     = "SafeLine WAF local-pure (100% local, zéro WAN Chaitin au runtime) — module terraform/safeline-lxc. Branch safeline-local-pure."
}

variable "tags" {
  type        = list(string)
  default     = ["waf", "safeline", "local-pure", "dynamic-backup"]
  description = "Tags Proxmox. dynamic-backup = convention backup de la stack pharos."
}

variable "enable_cloudinit" {
  type        = bool
  default     = true
  description = "Si true, injecte cloud-init.yaml (install Docker + bootstrapping) au premier boot. Le LXC doit être un template cloud-init capable (135 l'est)."
}

variable "cloudinit_user_data" {
  type        = string
  default     = ""
  description = "Seed cloud-init. Vide par défaut -> main.tf lit cloud-init.yaml du module (100% local au runtime). Surchargeable."
}

# ---- Secrets (chargés via TF_ env, JAMAIS commités) --------------------------
variable "proxmox_api_url" {
  type        = string
  default     = "https://172.16.0.5:8006"
  sensitive   = true
  description = "URL API du PVE (token chargé via TF_PROXMOX_API_URL)."
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Token Proxmox complet user@realm!token_id=token_secret. Chargé via TF_PROXMOX_API_TOKEN. Format : pharos-iac@pve!provisioning=<secret>."
}

# ---- Auth SSH (injection cloud-init) ----------------------------------------

variable "ssh_pubkey" {
  type        = string
  default     = ""
  description = "Clé publique SSH à injecter (cloud-init.user_account). Vide = aucune injection. Charger via TF_SSH_PUBKEY (par ex. contenu de ~/.ssh/id_ed25519.pub)."
}

# Injection de cle SSH dans le LXC (via Proxmox initialization.user_account).
# false par defaut : le template 135 n'est pas cloud-init capable (le champ est
# refuse). Passer a true UNIQUEMENT si le template choisi l'est.
variable "enable_ssh_inject" {
  description = "Injecte la cle SSH root via user_account (a true si le template est cloud-init capable)"
  type        = bool
  default     = false
}

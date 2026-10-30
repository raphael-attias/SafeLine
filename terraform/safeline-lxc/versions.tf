# versions.tf — pin des providers (compatible stack pharos homelab-iac).
# bpg/proxmox 0.70.1 = version exacte de la stack existante (jamais de drift).
# hashicorp/random : génération du mot de passe root LXC (sensible).
terraform {
  required_version = ">= 1.15.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.2"
    }
  }
  # Pas de backend local ici — le state est géré par la stack parent
  # (~/homelab-iac/terraform/terraform.tfstate, backend "local" du parent).
}

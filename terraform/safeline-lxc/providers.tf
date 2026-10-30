# providers.tf — EMBARQUÉ dans la stack pharos.
# Le provider "proxmox" est configuré par la stack parent
# (~/homelab-iac/terraform/providers.tf). Ce fichier est volontairement vide :
# aucun provider "proxmox" n'est redéclaré ici (héritage par défaut).
# Les variables proxmox_api_url / proxmox_api_token / ssh_pubkey restent
# déclarées dans variables.tf mais deviennent inoffensives (non référencées).

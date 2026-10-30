# outputs.tf — sorties (le mot de passe root est sensible).
output "lxc_vmid" {
  description = "VMID alloué au LXC SafeLine."
  value       = proxmox_virtual_environment_container.safeline.id
}

output "lxc_hostname" {
  description = "Hostname du LXC."
  value       = var.lxc_hostname
}

output "lxc_node" {
  description = "Nœud PVE qui héberge le LXC."
  value       = var.node_name
}

output "lxc_root_password" {
  description = "Mot de passe root du LXC (généré, sensible). À récupérer via `terraform output lxc_root_password`."
  value       = random_password.lxc_root.result
  sensitive   = true
}

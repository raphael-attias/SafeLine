# Alignement du state Terraform du LXC 136 (SafeLine local-pure)

## Contexte

Le LXC 136 (hostname safeline, 172.16.0.136/24, nœud pygargues) a été créé depuis le Mac
avec un state local. La stack de production vit sur pharos (`~/homelab-iac/terraform/`,
provider bpg/proxmox 0.70.1, state local). Le LXC a donc été importé dans cette stack
et le state local du Mac a été supprimé.

## Procédure suivie

1. Transfert du module vers `~/homelab-iac/terraform/modules/safeline-lxc/`.
2. Bloc `module "safeline"` dans `~/homelab-iac/terraform/safeline.tf` et variables ajoutées.
3. `terraform init`, puis `terraform import` du container 136.
4. Premier plan : remplacement forcé du container. Causes : `clone{}` et `operating_system{}`
   (arguments create-time only, non persistés après import) et `unprivileged` (absent du state).
5. Correctifs dans le module :
   - bloc `clone{}` supprimé ;
   - `operating_system` avec `template_file_id` factice (argument obligatoire) ;
   - `firewall = false`, aligné sur la réalité (net0 firewall=0) ;
   - `ignore_changes` étendu : disk, features, tags, network_interface, startup, console,
     initialization, operating_system, unprivileged ;
   - `prevent_destroy = true`.
6. `terraform apply -target=module.safeline` : crée `random_password.lxc_root`. La mise à jour
   en place du container (attributs purement Terraform : start_on_boot, timeouts, vm_id) a été
   refusée par Proxmox car le CT était verrouillé par une sauvegarde vzdump. Sans conséquence :
   le re-plan ciblé affiche "No changes".
7. Le state local du Mac a été retiré (`terraform.tfstate*`, `.terraform`).

## Relancer Terraform sur pharos sans secrets

```bash
ssh rapatt@pharos
set -a; source ~/homelab-iac/.env; set +a
export TF_VAR_target_node="pygargues" TF_VAR_proxmox_api_url="$PROXMOX_API_URL" \
  TF_VAR_proxmox_token_secret="$PROXMOX_TOKEN_ID=$PROXMOX_TOKEN_SECRET" \
  TF_VAR_proxmox_api_token="$PROXMOX_TOKEN_ID=$PROXMOX_TOKEN_SECRET" \
  TF_VAR_ssh_pubkey="$(cat ~/.ssh/id_ed25519.pub)"
cd ~/homelab-iac/terraform
terraform plan -input=false -target=module.safeline
```

Toujours cibler `-target=module.safeline` : le plan complet contient une dérive préexistante
sur fregate (LXC 1001) qui ne doit pas être appliquée ici.

Le fichier `.env` n'est jamais versionné ni copié.

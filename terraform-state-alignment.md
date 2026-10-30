# Alignement Terraform — LXC SafeLine 136 (state pharos)

**Date** : 2026-10-30 · **Branche** : `safeline-local-pure` · **Runtim** : pharos (`~/homelab-iac/terraform`)
**Ressource ciblée** : `module.safeline.proxmox_virtual_environment_container.safeline` (LXC vmid **136**, nœud `pygargues`)
**Objectif** : rendre le module `safeline` à **« No changes »** sans jamais détruire/replace le LXC 136 importé.

---

## 1. Problème de départ

`ignore_changes` ne stabilisait pas le LXC 136 : le plan proposait un **`must be replaced`**
(destructeur) à chaque `terraform plan`. Hypothèse initiale : les blocs `clone` et
`operating_system` seraient des attributs *create-time-only* non persistés dans le state
après `terraform import`, vus comme « configurés mais inconnus » → replacement forcé.

## 2. Diagnostic réel (preuves par le plan)

L'inspection du state importé a révélé :

| Attribut | Dans le state ? | Cause du replacement | `ignore_changes` efficace ? |
|---|---|---|---|
| `clone` | **NON** (write-only, jamais écrit) | configuré mais absent du state → « create » | **NON** (create-time write-only) |
| `operating_system` | **OUI** (`type="ubuntu"`) | présent au state, absent du config → diff « remove », **ForceNew** | **OUI** |
| `unprivileged` | **NON** | forcé à `true` en config, **ForceNew** | **OUI** |
| `start_on_boot` | **NON** | forcé à `true` en config, update in-place | OUI |

Le plan de la première passe (après suppression du bloc `clone`) montrait **exactement deux**
marqueurs `# forces replacement` :

```
+ unprivileged   = true # forces replacement
- operating_system { # forces replacement
    - type             = "ubuntu" -> null
  }
```

→ La correction initiale (`clone` + `operating_system` hors `ignore_changes`) était
**nécessaire mais insuffisante** : le vrai remède est de (a) supprimer le bloc `clone`
(write-only, hors de portée de tout `ignore_changes`) ET (b) **ré-introduire**
`operating_system` + `unprivileged` dans `ignore_changes` (ils SONT stabilisables,
contrairement à `clone`).

## 3. Fix appliqué sur `terraform/safeline-lxc/main.tf`

1. **Bloc `clone { ... }` supprimé** (il n'avait plus de rôle : le LXC 136 est déjà cloné depuis 135 à sa création).
2. **Bloc `operating_system` rétabli** avec une `template_file_id` factice (`RAID6S:vztmpl/placeholder-import.tar.zst`)
   + `type="ubuntu"`, **ignoré** par `ignore_changes` (évite le diff « remove »).
3. **`unprivileged = true`** conservé en config (reel PVE : `unprivileged=1`) mais **ignoré** par `ignore_changes`.
4. **`lifecycle` renforcé** :
   ```hcl
   lifecycle {
     prevent_destroy       = true   # ceinture : bloque tout destroy/replace accidentel
     create_before_destroy = false
     ignore_changes = [
       disk, features, tags, network_interface, startup,
       console, initialization,
       operating_system, unprivileged,
     ]
   }
   ```

**Effet « ceinture » vérifié** : la première passe a déclenché le `must be replaced`,
mais `prevent_destroy` a **bloqué** le plan (erreur `Instance cannot be destroyed`) →
**0 impact sur le LXC 136**. Le remède ci-dessus a ensuite supprimé les deux forces-replacement.

## 4. Preuves

### 4.1 Première passe — forces replacement + prevent_destroy bloquant
```
# module.safeline.proxmox_virtual_environment_container.safeline must be replaced
  + unprivileged   = true # forces replacement
  - operating_system { # forces replacement
      - type  = "ubuntu" -> null
    }
Plan: 2 to add, 1 to change, 1 to destroy.

Error: Instance cannot be destroyed
  on modules/safeline-lxc/main.tf line 36
Resource module.safeline...safeline has lifecycle.prevent_destroy set, but the plan
calls for this resource to be destroyed.
```

### 4.2 Plan final — module.safeline ABSENT du corps du plan
```
$ terraform plan -no-color -input=false
module.safeline.random_password.lxc_root: Refreshing state... [id=none]
module.safeline.proxmox_virtual_environment_container.safeline: Refreshing state... [id=136]
proxmox_virtual_environment_container.lxc[0]: Refreshing state... [id=1001]

  # proxmox_virtual_environment_container.lxc[0] will be updated in-place   <-- fregate, HORS-SCOPE

Plan: 0 to add, 1 to change, 0 to destroy.
```
→ `module.safeline` n'apparaît **que** dans les lignes de *refresh* (état lu, non modifié) :
**NO CHANGES** pour le module. Le seul changement pendu est le drift fregate (`lxc[0]`, hors-scope).

### 4.3 Apply scopé (fregate préservé)
```
$ terraform apply -auto-approve -no-color -input=false -target=module.safeline
module.safeline.proxmox_virtual_environment_container.safeline: Refreshing state... [id=136]
module.safeline.random_password.lxc_root: Refreshing state... [id=none]

No changes. Your infrastructure matches the configuration.
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```
L'apply a été **scopé à `-target=module.safeline`** (et non global) pour **ne pas appliquer
le drift fregate** (`proxmox_virtual_environment_container.lxc[0]` : réordonnancement de tags
+ `memory.dedicated 6144 -> 4096`), explicitement déclaré hors-scope.

### 4.4 State final (pharos) — 3 ressources, module.safeline complet
```
$ terraform state list
proxmox_virtual_environment_container.lxc[0]
module.safeline.proxmox_virtual_environment_container.safeline
module.safeline.random_password.lxc_root

$ terraform state list | grep safeline   # -> 2 ressources
module.safeline.proxmox_virtual_environment_container.safeline
module.safeline.random_password.lxc_root
```

## 5. Divergence assumée avec le diagnostic d'origine

Le message initial préconisait de **retirer `operating_system` d'`ignore_changes`** et de
supprimer son bloc, au motif qu'il serait create-time non persisté. L'empirique contredit
cela : `operating_system` **est** persisté dans le state (`type="ubuntu"`), et c'est précisément
son **suppression** (diff « remove ») qui forçait le replacement. Le bon remède est donc
l'**inverse** : le réintroduire (factice, ignoré) + ignorer `unprivileged`. Seul `clone`
était réellement hors de portée d'`ignore_changes` (write-only), d'où sa suppression pure.

## 6. Hygiène & sécurité

- **Jamais de destroy/replace** du LXC 136 : `prevent_destroy=true` + apply `-target=module.safeline`.
- **fregate non touché** : drift préservé (hors-scope).
- **Auth PVE** : `Authorization: PVEAPIToken=<token_id>=<secret>` (préfixe `PVEAPIToken=`
  obligatoire), token `pharos-iac@pve!provisioning`, endpoint `https://172.16.0.5:8006`.
  Secrets chargés depuis `~/homelab-iac/.env` (`PROXMOX_API_URL`/`PROXMOX_TOKEN_ID`/`PROXMOX_TOKEN_SECRET`),
  **jamais committés** (`.gitignore` : `.terraform/`, `*.tfstate*`, `*.tfvars*`).
- **State Mac purgé** : `terraform.tfstate*`, `.terraform/`, `.terraform.lock.hcl` retirés du
  module Mac (le runtime de référence est pharos ; le Mac ne fait qu'éditer `main.tf` + git).
- **GPL-3.0 préservée** ; **aucun push vers `upstream` (chaitin/SafeLine)** ; push sur
  `origin`/`fork` (raphael-attias/SafeLine) uniquement.

# Déploiement SafeLine local-pure dans le LXC 136

Date : 2026-10-30. Hôte : LXC 136 (pygargues), 172.16.0.136/24, Ubuntu 22.04, 4 vCPU, 4 Go, disque 7,8 Go.
Alignement Terraform : voir terraform-state-alignment.md.

## Stack

- Docker 29.9.2 et Compose v5.6.1 (installés via get.docker.com), répertoire /opt/safeline.
- Image mgt `safeline-mgt:local-pure` buildée sur le Mac (amd64) puis chargée dans le LXC.
- Images chaitin en 9.4.2 : detector, tengine, luigi, fvm, chaos ; postgres 15.2.
- Sept conteneurs actifs : pg, mgt, detector, tengine, luigi, fvm, chaos.
- Fichier .env en chmod 600, mot de passe PostgreSQL aléatoire (openssl rand -hex 16), non versionné.
- Certificats gRPC générés par `/app/mgt -gen_certs` dans /opt/safeline/resources/management/certs.

## Écarts par rapport au compose du fork

- Image mgt remplacée par la référence littérale `safeline-mgt:local-pure`.
- `MGT_PG` remplacé par `DATABASE_URL` : le fork lit DATABASE_URL (management/webserver/pkg/config/db.go).
  Sans cela mgt cherchait PostgreSQL sur 127.0.0.1 et redémarrait en boucle.
- Volume ajouté sur mgt : resources/management/certs vers /resources/management/certs
  (sinon "grpc_server.crt: no such file").
- REGION= ajouté dans .env (variable référencée par le compose).
- Les tags `latest` tirés au premier essai ont été remplacés par les tags 9.4.2 attendus par le compose.
- Le LXC n'a pas d'IPv6 : un premier pull de couche a échoué, relancé avec succès en IPv4.

## Résultats

- `GET /api/Ping` sur https://172.16.0.136:9443 : 200, `{"message":"pong"}`.
- `GET /api/UpgradeTips` : 200, `{"data":{"upgrade_tips":0},"err":null,"msg":""}`.
- Capture de /proc/net/tcp et tcp6 du conteneur mgt : .build-local/runtime/mgt-net-AFTER-LXC.txt.
  Décodage : un seul pair non local, 192.168.2.246 (le Mac de l'opérateur, requête curl, état TIME_WAIT).
  Aucune connexion vers les IP Chaitin 121.43.103.178, 120.55.248.217, 121.196.236.254
  (grep nul dans la capture et dans les logs mgt).
- Au démarrage mgt journalise "Failed to compile and save fsl (degraded, offline)" : mode dégradé hors ligne,
  à examiner si les règles FSL sont attendues.

## Test SQLi

Conteneur `sqli-test-app` (mendhak/http-https-echo) créé sur le réseau safeline_safeline-ce, port 18080.
Aucune application n'est encore définie dans la console SafeLine, rien n'écoute sur le port 80.
Les quatre payloads (UNION SELECT, OR 1=1, DROP TABLE, XSS) avec `Host: test.local` renvoient donc
une connexion refusée (code 000) : non concluant. Aucune trace blocked, attack, sql, injection ou xss
dans les logs tengine et detector.

À compléter après création de l'application (console web) : domaine test.local, port 80,
upstream http://sqli-test-app:80, sans SSL. Puis rejouer les payloads.

## Ressources

Disque : 4,2 Go utilisés sur 7,8 Go (57 %), 3,2 Go libres. Tengine consomme environ 1,4 Go de RAM sur 4 Go.
Le disque est correct mais deviendra juste avec les logs et les données PostgreSQL.

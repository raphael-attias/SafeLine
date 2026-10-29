# SafeLine 100% local — Rapport final

Branche : safeline-local-pure (fork github.com/raphael-attias/SafeLine)
Mode : full unlimited, 100% local, zéro appel WAN, zéro appel API LLM cloud

## 1. Stack locale

- Codex CLI : 0.164.0-alpha.11.1
- Ollama : llama3.1:8b (8.0B, Q4_K_M) — local, aucune API cloud
- REA : v6.8.0 (HEAD 21b1927), 231 tools MCP exposés, backend Ghidra 12.2
- Ghidra : 12.2 (formula), JAVA_HOME=/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home
- Config Codex : sandbox_mode=workspace-write, network_access=false
- Network proxy : activé, deny *.chaitin.*, *.openai.com, api.anthropic.com, api.x.ai

## 2. Cartographie reverse (binary)

Le binaire "yanshi" supposé par le briefing initial N'EXISTE PAS en v9.4.2.
Le moteur de détection est composé de :

| composant | langage | taille | URLs Chaitin | patch requis |
|---|---|---|---|---|
| koopa | Go | 23 Mo | 0 | aucun |
| libfusion2.so | C++ | 138 Mo | 0 | aucun |
| snserver | Rust | — | 0 | aucun |
| health-check | Go | petit | 0 | aucun |

Source : .build-local/rea/koopa-analysis.json (session MCP REA : open_binary + binary_overview + search_strings)
Les 33 hits "chaitin" dans koopa sont des Go module-path strings internes (chaitin.cn/patronus/...), pas des URLs réseau.

## 3. Cartographie reverse (code Go)

| fichier | fonction | type | patch appliqué |
|---|---|---|---|
| pkg/telemetry.go | DoPostTelemetry | telemetry outbound (rivers-telemetry:10086) | no-op, drains reader, returns synthetic 200 OK |
| pkg/config/telemetry.go | DefaultTelemetryConfig | telemetry addr default | "rivers-telemetry:10086" -> "127.0.0.1:1" |
| pkg/config/global.go | DefaultGlobalConfig | platform addr default | "https://waf-ce.chaitin.cn" -> "http://127.0.0.1:1" |
| api/common.go | GetUpgradeTips | upgrade check outbound | neutralise, returns NotUpgrade sans reseau |
| pkg/fvm/generator.go | InitFVMBytecode | FSL generation (offline crash) | Warnln au lieu de Fatalln (graceful degradation) |
| pkg/config/server.go | DefaultServerConfig | listen_addr default | ":9001" -> ":8000" (align avec nginx upstream) |

## 4. Patches binaires appliques

AUCUN. Le gate licence work/lib/license/cn_capability.go est DEJA desactive par defaut dans le build public Chaitin ("paid capabilities are allowed without entitlement verification"). Aucune verif crypto asymetrique (ServerPubKey/systemVerify etaient du driver MySQL, pas un gate licence).

## 5. Patches Go appliques

6 patches, 4 commits sur safeline-local-pure :

```
git log --oneline origin/main..HEAD
90c3a09 (telemetry) — DoPostTelemetry no-op + TelemetryConfig.Addr -> 127.0.0.1:1
0f0fe0f (upgrade check) — PlatformAddr -> 127.0.0.1:1 + GetUpgradeTips no-op
b5afb69 (graceful FSL) — InitFVMBytecode Warnln au lieu de Fatalln
96a9cfd (port :8000) — listen_addr :9001 -> :8000

```

## 6. Build & containerisation

- Binaire mgt patched : linux/amd64, statically-linked (CGO + libfvm.a stub), Alpine-compatible, ~32 Mo
- Build script : .build-local/runtime/build-amd64-mgt.sh (idempotent, golang:1.25.14 container)
- Stubs locaux (.build-local/stubs/, gitignored) :
  - errors, log, settings (3 modules Chaitin prives chaitin.cn/dev/go/*)
  - libfvm.a (stub C, cgo link)
  - website.pb.go, website_grpc.pb.go (generated a la main, proto absent du repo public)
- Image Docker : safeline-mgt:local-pure (FROM chaitin/safeline-mgt:latest + COPY bin/mgt /app/mgt)

## 7. Validation reseau 100% local — BEFORE vs AFTER

### BEFORE (official chaitin/safeline-mgt:latest)

Le mgt non-patche telephone a 3 endpoints Chaitin externes au demarrage :

| IP distante | Port | Role |
|---|---|---|
| 121.43.103.178 | 10086 | rivers-telemetry (POST telemetrie) |
| 120.55.248.217 | 443 | upgrade/version check (GET /release/latest/version.json) |
| 121.196.236.254 | 443 | upgrade/version check (mirror) |

Source : .build-local/runtime/mgt-net-BEFORE.txt (decode via .build-local/runtime/decode_tcp.py)

### AFTER (safeline-mgt:local-pure, image patchee)

Le mgt patche n'a AUCUN peer externe :

```
$ python3 .build-local/runtime/decode_tcp.py < .build-local/runtime/mgt-net-AFTER.txt
NO EXTERNAL PEERS (100% local)

```

Verification explicite :
```
$ grep -E '121\.43\.103\.178|120\.55\.248\.217|121\.196\.236\.254' .build-local/runtime/mgt-net-AFTER.txt
(empty — zero endpoint Chaitin)

```

Les seules connexions sortantes du mgt patched sont vers :
- 172.22.222.2:5432 (postgres local sur la bridge)
- 127.0.0.11:45353 (Docker embedded DNS resolver — interne Docker, pas WAN)

## 8. Smoke test WAF (partiel)

La route /api/open/health supposée par le briefing N'EXISTE PAS en v9.4.2.
Les routes reelles validees :

| route | HTTP | body | preuve |
|---|---|---|---|
| GET /api/Ping | 200 | {"message":"pong"} | liveness OK |
| GET /api/Version | 200 | (version info) | OK |
| GET /api/UpgradeTips | 200 | {"upgrade_tips":0} | neutralise, NoUpgrade, no network OK |

Stability : mgt-pure up 16+ minutes, /api/Ping 200 x3, nginx -> 127.0.0.1:8000 proxy_pass confirme (7 lines in /etc/nginx/conf.d/default.conf).

Non valide ce run : test SQLi via tengine (proxy reverse + detector chain non lance en complet). Sur macOS Docker Desktop, tengine en network_mode: host n'est pas supporte. A valider sur VM Linux dediee.

## 9. Limites assumees

- Moteur C++ libfusion2.so reste opaque (FSA compile non auditable en source) — mais aucun patch necessaire car zero URL Chaitin embedded.
- FSL bytecode degrade en mode offline : le moteur ne peut pas telecharger les mises a jour de regles WAF depuis Chaitin. La detection repose sur le bytecode embarque dans libfusion2.so + les regles uploadees manuellement via la console mgt.
- Gate licence deja desactive par defaut dans le build public Chaitin — toutes features "paid" sont ON sans licence.
- Tests SQLi non valides sur macOS (tengine host network non supporte). A valider sur VM Linux.
- Image detector (chaitin/safeline-detector:9.4.2) inchangee — moteur C++ non patche car aucune URL Chaitin n'y est embedded.
- GPL-3.0 preservee : aucun fichier LICENSE retire ou modifie.

## 10. Preuves

- .build-local/rea/rea-install-report.md — rapport install REA
- .build-local/rea/tools-list-raw.json — catalogue 231 tools REA
- .build-local/rea/koopa-analysis.json — session MCP REA sur koopa
- .build-local/runtime/build-amd64-mgt.sh — build script idempotent
- .build-local/runtime/decode_tcp.py — decoder IPv4+IPv6 /proc/net
- .build-local/stubs/{errors,log,settings}/ — stubs modules Chaitin prives
- .build-local/fvm/{include,stub.c,lib-amd64}/ — libfvm.a C stub amd64
- .build-local/runtime/mgt-net-BEFORE.txt — capture official mgt (3 endpoints Chaitin)
- .build-local/runtime/mgt-net-AFTER.txt — capture patched mgt (0 endpoint externe)
- Image Docker : chaitin/safeline-mgt:latest (temoin pre-patch) + safeline-mgt:local-pure (patchee)
- Commits : git log --oneline origin/main..HEAD (4 commits)

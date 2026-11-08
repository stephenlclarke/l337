# Complete original fleet: one-branch implementation backlog

Date: 2 November 2026. Dedicated implementation owner: G4. Branch: `feat/complete-original-fleet`.

The human requested continuous fleet implementation on one branch, followed by one coherent integration and merge. Code the complete batch before maintained integration. Preserve combat and mission execution in their existing workspace. Development commits may accumulate on the fleet branch.

## Baseline and completion rules

The R3 fleet contains 162 ships, six stations and three other entries (one capsule, one platform and one probe). Explicit new-runtime routing exists for 23 ships and four stations. The remaining connection backlog is **139 ships, two stations and three other entries: 144 total**. Existing runtime connections are not gameplay acceptance; all 171 entries remain in the final checks.

Track authored, reviewed, integrated, tested and actual-game-accepted counts separately. Do not increase the runtime or accepted counts for a pending-only visual asset. Keep hard blockers explicit and continue coding independent entries; do not stop the fleet lane at a per-hull report.

Use the immutable R3 archive and per-entry hashes in [FLEET-BACKLOG.json](FLEET-BACKLOG.json). Preserve later selected per-ID resource and physical corrections. No old-name/model fallbacks, missing collision, free equipment/crew, arbitrary mass or geometry-cap waiver.

## Required work packages

- **AUTHORITY**: Use exact current R3 name, role, performance, access, accommodation, fitting and acquisition contract; preserve selected later per-ID geometry/physical winners. Resolve explicit missing design choices without reusing old aliases or inventing equipment/crew grants.
- **RESOURCE**: Install original full geometry, materials, textures, UVs and legitimate notices. Replace old model/profile/name/alias dependencies. Candidate assets without runtime use do not count as connected.
- **PHYSICAL**: Provide calibrated per-ID units, qualified closed native collision at the existing face cap, actual port where applicable, and a justified physical mass/inertia/energy contract. Preserve authored gaps/material and real limitations; no proxy/cap waiver or assumed equivalence.
- **RUNTIME**: Connect strict loader/catalogue/definition/physical routing. No family-name/default preview/old-generated/native alias fallback. Pending-only assets do not satisfy this task.
- **PERSISTENCE**: Make fresh/current save-load, custody, ownership, discovery and receipts coherent with the existing writer. No migration or old-save compatibility layer.
- **TESTS**: Implement meaningful per-ID and shared regression coverage for load, physical admission, acquisition, fitting/crew, NPC/salvage, save and failure rollback; register genuine method identities. Run through G1 after the coherent batch is coded.
- **RENDER**: After coding, G1 generates actual full-fleet views and README-scale media; inspect all views, glazing supports, ports, materials and dimensions.
- **GAME**: After integration, G1 verifies actual ordinary gameplay paths and records evidence; static source checks and controlled fixture setup are not completed game journeys.
- **STATION_SERVICE**: Connect correct original station population/sites/services/docking, living body and history/loss rules, source authority and never-purchase rules; preserve selected SH028 versus secondary-station policies.
- **NPC**: Connect actual supported NPC roles, availability/placement, native body construction, damage, crew/custody and salvage. Declared metadata alone is insufficient.
- **ACQUISITION**: Implement exact R3/selected later purchase or earned blueprint policy, paid exchange, prerequisite/milestone/discovery validation, quote-confirm freshness and writer rollback. EMP disable or a kill alone must not grant salvage blueprints unless expressly authorized.
- **FIT_CREW**: Enforce actual paid equipment, capacity, cargo, accommodation and finite crew requirements, default bare-hull limits and normal launch checks; no free role kit or invisible stock.
- **MEDUSA_Q01**: Connect all core clues/PLUGH and ordered finale prerequisites, actual EMP disable, lawful physical cut/scoop and receiving. Preserve paid-stock versus upgraded outcomes; not kill-only.

- **CAPSULE_ESCAPE**: Connect actual escape-pod launch, physical occupancy, damage, rescue/custody and durable outcomes; preserve its explicit nonstandard access instead of forcing normal player-hull purchase.

- **PLATFORM_SERVICE**: Connect original platform placement, physical body and services, damage/discovery/collection rules and never-purchase policy as the per-ID R3 contract requires.

- **PROBE_BEHAVIOR**: Connect the original probe/object-specific native behavior, encounter and damage/discovery/current-save rules; do not force a normal ship adapter.

## Ships requiring runtime connections

| ID | Original R3 name | Family | Purchase policy | Required work |
| --- | --- | --- | --- | --- |
| SH001 | Mule | mule | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH008 | Goshawk Explorer | goshawk | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH009 | Goshawk Mk II | goshawk | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH010 | Goshawk Mk II Custom | goshawk | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH011 | Goshawk Scout | goshawk | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH015 | Raven | raven | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH016 | Mole Miner | mole | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH017 | Mole Prospector | mole | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH020 | Crow Prototype | crow | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH021 | Zebra | zebra | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH022 | Peregrine Mk I | peregrine | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH023 | Peregrine Mk III | peregrine | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH024 | Peregrine Mk IV | peregrine | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH036 | Zebu | zebu | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH037 | Vulture Mk I | vulture | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH038 | Vulture Mk II | vulture | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH039 | Vulture Mk III | vulture | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH041 | Serval Fighter | serval | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH042 | Saker | saker | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH043 | Eagle Cruiser | eagle | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH044 | Harpy Assault | harpy | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH045 | Erne Corvette | erne | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH046 | Harpy Dropship | harpy | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH047 | Harpy Gunship | harpy | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH048 | Lanner | lanner | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH049 | Hyena | hyena | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH050 | Yak | yak | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH051 | Jackal | jackal | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH052 | Banteng | banteng | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH053 | Caracal Scout | caracal | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH054 | Hobby Fighter | hobby | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH055 | Condor | condor | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH056 | Aplomado Interceptor | aplomado | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH057 | Falconet | falconet | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH058 | Muskox | muskox | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH059 | Barbary | barbary | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH060 | Wombat | wombat | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH062 | Moose Clipper | moose | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH063 | Seriema Courier | seriema | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH064 | Arna Cutter | arna | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH065 | Vulture Raider | vulture | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH066 | Rabbit Explorer | rabbit | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH067 | Rhinoceros Trader | rhinoceros | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH068 | Badger | badger | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH069 | Baza Fighter | baza | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH070 | Baza Mk II | baza | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH071 | Griffon | griffon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH072 | Griffon Mk II | griffon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH073 | Griffon Spectre | griffon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH074 | Dzo | dzo | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH075 | Dzo Mk II | dzo | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH076 | Hog | hog | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH077 | Tamaraw | tamaraw | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH078 | Oryx Voyager | oryx-voyager | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH079 | Carabao Freighter | carabao | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH080 | Carabao Highliner | carabao | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH081 | Jaguar | jaguar | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH082 | Cheetah | cheetah | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH083 | Hare Explorer | hare | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH084 | Llama | llama | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH085 | Laggar | laggar | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH086 | Alpaca | alpaca | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH087 | Elk | elk | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH088 | Springbok Starliner | springbok | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH089 | Antelope | antelope | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH090 | Elephant | elephant | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH091 | Gopher | gopher | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH092 | Aurochs | aurochs | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH093 | Giraffe Liner | giraffe | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH094 | Shikra | shikra | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH095 | Shikra Interdictor | shikra | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH096 | Wisent | wisent | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH097 | Wisent Mk II | wisent | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH098 | Anoa | anoa | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH099 | Ox | ox | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH100 | Ox Mk II | ox | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH101 | Cavy Racer | cavy | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH104 | Wildebeest | wildebeest | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH105 | Tapir Shuttle | tapir | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH106 | Tapir Mk II | tapir | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH107 | Magpie | magpie | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH109 | Hippo | hippo | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH110 | Leopard Fighter | leopard | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH111 | Puma | puma | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH112 | Larvaal Warden | larvaal-warden | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH113 | Larvaal Ravager | larvaal-ravager | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH114 | Larvaal Sentinel | larvaal-sentinel | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH115 | Larvaal Lancer | larvaal-lancer | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH116 | Larvaal Broodlord | larvaal-broodlord | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH117 | Larvaal Provoker | larvaal-provoker | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH118 | Larvaal Reaver | larvaal-reaver | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH119 | Larvaal Wraith | larvaal-wraith | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH120 | Larvaal Seeker | larvaal-seeker | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH121 | Larvaal Mender | larvaal-mender | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH122 | Larvaal Harvester | larvaal-harvester | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH123 | Larvaal Sovereign | larvaal-sovereign | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH124 | Larvaal Warship | larvaal-warship | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH125 | Larvaal Drone | larvaal-drone | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH126 | Mangalica | mangalica | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH127 | Gaur Trader | gaur | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH128 | Boar Transport | boar | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH129 | Warthog Escort | warthog | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH130 | Marmot Prospector | marmot | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH131 | Warthog Light | warthog | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH132 | Warthog Freighter | warthog | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH133 | Warthog Tanker | warthog | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH134 | Warthog Heavy | warthog | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH135 | Javelina | javelina | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH136 | Falcon Mk I | falcon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH137 | Falcon Mk II | falcon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH138 | Falcon Mk III | falcon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH139 | Falcon Mk IV | falcon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH140 | Chimango | chimango | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH142 | Buzzard Mk II | buzzard | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH143 | Aardvark Miner | aardvark | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH144 | Razorback | razorback | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH145 | Kestrel | kestrel | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH146 | Merlin | merlin | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH147 | Hawk | hawk | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH148 | Morepork | morepork | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH149 | Owlet Mk II | owlet | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH150 | Reindeer Freighter | reindeer | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH151 | Lynx Escort | lynx | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH152 | Osprey Scout | osprey | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH153 | Osprey Strike | osprey | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH154 | Osprey Patrol | osprey | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH155 | Osprey Support | osprey | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH157 | Wolf Scout | wolf | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH158 | Wolf Mk I | wolf | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH159 | Wolf Mk II | wolf | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH160 | Wolf Cutter | wolf | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH163 | Lammergeier | lammergeier | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH165 | Secretarybird | secretarybird | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH166 | Camel Rescue | camel | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH167 | Secretarybird Survey | secretarybird | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH168 | Armadillo Miner | armadillo | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH169 | Caracara Mk I | caracara | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH170 | Caracara Mk II | caracara | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH171 | Medusa | medusa | plughQuestFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW, MEDUSA_Q01 |

## Stations requiring runtime connections

| ID | Original R3 name | Family | Purchase policy | Required work |
| --- | --- | --- | --- | --- |
| SH161 | Wolf Citadel | wolf | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, STATION_SERVICE |
| SH164 | Toad Drug Factory | toad-drug-factory | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, STATION_SERVICE |

## Other craft and platforms requiring runtime connections

| ID | Original R3 name | Object kind | Purchase policy | Required work |
| --- | --- | --- | --- | --- |
| SH040 | Newt Escape Pod | capsule | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, CAPSULE_ESCAPE |
| SH156 | Lion Bastion | platform | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, PLATFORM_SERVICE |
| SH162 | Larvaal Probe | other | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, PROBE_BEHAVIOR |

## Already connected entries with acceptance still open

| ID | Original R3 name | Family | Purchase policy | Required work |
| --- | --- | --- | --- | --- |
| SH002 | Gyrfalcon Assault | gyrfalcon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH003 | Gyrfalcon Command | gyrfalcon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH004 | Gyrfalcon Patrol | gyrfalcon | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH005 | Bison | bison | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH006 | Bison Mk II | bison | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH007 | Impala Voyager | impala | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH012 | Sable Liner | sable-liner | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH013 | Buffalo | buffalo | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH014 | Buffalo Mk II | buffalo | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH018 | Onager | onager | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH019 | Gazelle Explorer | gazelle | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH025 | Peregrine Mk V | peregrine | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH026 | Harrier | harrier | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH027 | Ibex | ibex | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH028 | Lion Citadel | lion-citadel | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, STATION_SERVICE |
| SH029 | Okapi | okapi | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH030 | Sparrowhawk | sparrowhawk | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH031 | Kite Interceptor | kite | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH032 | Panther Explorer | panther | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH033 | Panther Scout | panther | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH034 | Frog Station | frog | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, STATION_SERVICE |
| SH035 | Stag Liner | stag | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH061 | Saiga | saiga | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH102 | Dhole Haven | dhole | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, STATION_SERVICE |
| SH103 | Redtail Mk III | redtail | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH108 | Besra | besra | blueprintFabrication | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, NPC, ACQUISITION, FIT_CREW |
| SH141 | Salamander Station | salamander-station | never | AUTHORITY, RESOURCE, PHYSICAL, RUNTIME, PERSISTENCE, TESTS, RENDER, GAME, STATION_SERVICE |

## Final batch acceptance

G1 reviews and integrates the completed branch after independent review; resolves conflicts and actionable findings; builds and runs meaningful affected and broader tests; checks actual game acquisition, flight, NPCs, salvage, docking and current saves; generates and inspects actual renderer media; completes required final-head CI and protected merge. Fix issues on this same branch/change. No new release or M02/M03 completion until the connected game requirements pass.

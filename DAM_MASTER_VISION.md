# DAM — Master Vision

## 1. Project identity
**DAM (دم)** is an Android-first 3D real-time strategy game built with Godot 4.3. It evolves from the current Open RTS codebase already in this repository. Development continues in-place; do not restart the project or create a replacement repository.

The target experience is an original, full, polished mobile RTS with fast base building, strong faction identity, land/air/naval warfare, resource pressure, strategic powers, special abilities, skirmish AI, campaign missions, and readable cinematic presentation. DAM may feel familiar to players of games such as *Red Alert*, but it is not designed around reproducing Red Alert's rules, factions, balance, structure, or content. DAM defines its own gameplay systems, names, art, audio, story, factions, units, maps, UI, progression, and balancing.

## 2. Product principles
- Android is the primary platform and touch is a first-class control scheme.
- Fast, readable RTS gameplay; short input paths and minimal menu friction.
- Three genuinely different factions, not cosmetic reskins.
- Combined arms: infantry, armor, artillery, aircraft, naval forces and support units.
- Every important unit should have a tactical role; advanced units may have an active ability.
- Build a reusable data-driven RTS architecture so content can grow without rewriting core systems.
- Optimize continuously for mobile hardware rather than porting a desktop UI at the end.
- GitHub Actions produces installable APK artifacts; milestones must remain buildable.


## 2A. Real-world map engine
DAM's strategic space is built like a real map/terrain application first, then gameplay is layered on top. The player should see one continuous geographic world rather than visible square terrain blocks.

The first bounded implementation is the Middle East. Runtime streaming keeps only the visible neighborhood loaded. At strategic zoom levels the visual surface is a real map texture draped over real 3D elevation geometry. The raster tiles are an internal delivery mechanism only; tile edges must not be presented as game-world boundaries.

The prototype uses OpenStreetMap standard raster tiles for the visible geographic surface and Terrarium DEM tiles for elevation. OpenStreetMap use is limited to interactive prototype viewing with attribution and a small time-limited cache; DAM must not bulk-download the public tile service. Production will move to self-hosted/packaged map data suitable for offline regional downloads.

Later map layers are independent of the visual basemap: vector roads, buildings, railways, bridges, tunnels, airports, ports, waterways, land cover, administrative areas and gameplay resources. Those layers will drive gameplay and pathfinding rather than relying on pixels in the raster map.

High-resolution satellite imagery is planned as an optional selectable regional package. A player can use the standard map without satellite imagery, then download higher-detail imagery only for regions they choose. The satellite layer must use a source whose license explicitly permits the intended distribution/offline use.

Political and control layers are versioned data snapshots with source/date provenance. DAM does not silently redraw disputed political geography.

### Map milestone currently under test
- continuous 3D WGS84 terrain
- real DEM elevation
- OpenStreetMap surface texture
- portrait/landscape Android rotation
- touch pan and pinch zoom
- zoom levels 4–10
- wider visible tile neighborhood to prevent an isolated floating patch
- dedicated MAP / TERRAIN visual toggle using DEM-derived hillshade
- retained off-screen tile ring so panning does not immediately punch holes in the map
- map appears flat/textured first if necessary, then upgrades to real elevation as DEM arrives

### Classic-RTS terrain translation
DAM does not treat the visible map image as the battlefield. The classic Westwood/Red Alert approach is the design reference: maps are cell/tile based, terrain has explicit height levels, slopes/ramps connect levels, cliffs affect movement, and terrain art is layered separately from gameplay geometry. DAM translates that structure from real geographic evidence instead of hand-painted fictional terrain.

Current prototype translation:
- WGS84 coordinates provide real horizontal placement.
- DEM elevation is quantized into RTS-readable height levels.
- Terrain view uses an isometric/perspective battlefield camera rather than the strategic top-down map camera.
- Vertical relief is intentionally exaggerated for readability while horizontal geography remains tied to the real source position.
- The temporary OSM raster is blurred/abstracted in terrain mode so labels and cartographic ink do not become the battlefield art.
- Later vector layers will generate roads, buildings, bridges, water edges and movement rules from real data, equivalent to how classic RTS terrain tiles carried passability and ramp/cliff meaning.
- Strategic MAP mode and playable TERRAIN mode are separate presentations of the same geographic state.

### Real-data battlefield generator
The playable terrain is not a tilted raster map. DAM uses two presentations of one geographic state:

- **MAP**: strategic cartographic view with real names and boundaries.
- **TERRAIN**: isometric RTS battlefield generated from real data.

The first terrain generator uses real DEM elevation for the ground mesh and OpenStreetMap vector geometry for road centerlines, building footprints, waterways and place names. Arabic place names are preferred when an OSM `name:ar` tag exists; otherwise the normal `name` tag is retained. Buildings are positioned from their real footprints and use tagged height/level information where available. Roads follow their real geographic geometry. Names remain separate 3D labels rather than being baked into the ground texture.

The Red Alert reference is structural, not geographic: readable isometric camera, terrain that affects play, roads/buildings/water as independent gameplay layers, and clear visual hierarchy. Geography itself remains derived from published real-world data.

The vertical terrain is visually exaggerated for RTS readability while horizontal positions remain tied to real coordinates. The underlying real elevation is preserved in the data pipeline so later movement/slope rules do not need to infer height from artwork.

### Aleppo first-city milestone
The first production-quality real-world battlefield is deliberately narrowed to **Aleppo city** before scaling to Aleppo Governorate and then neighboring countries. The purpose is to finish one dense real city correctly rather than repeatedly testing the whole Middle East.

The current Aleppo sector is centered on the real city coordinates and bundles a build-time OpenStreetMap snapshot for a central test area. The snapshot contains real building footprints, roads, waterways and place labels. Terrain elevation remains streamed from DEM data. Arabic names are preferred where the source includes them.

This is a development sector, not yet the full Aleppo Governorate. Once its terrain, buildings, roads, labels, streaming and Android performance are verified on-device, the exact same generator will be extended by adjacent sectors until the governorate is continuous.

### Syria 14-governorate milestone
DAM's current geographic scope is Syria only. The Android prototype now treats the fourteen governorates as selectable detailed test sectors built by one shared compiler and one shared Cell Engine. Aleppo remains the default because it is the first visually verified sector.

The build pipeline downloads one current Syria OpenStreetMap extract, scans it once, and creates a compact runtime dataset for each governorate. Each sector preserves real road geometry, real building footprints, waterways and place names around the governorate's main urban center, while the DEM terrain continues to stream separately. The fourteen datasets are not fourteen separate game engines; they are fourteen inputs to the same Syria world engine.

This milestone intentionally gives every governorate a working Aleppo-style sector before expanding each sector outward to continuous full-governorate coverage. This keeps Android performance measurable while avoiding a return to a single giant Middle East dataset.

## 3. Current foundation
The repository already provides basic RTS foundations including resources, terrain/air units, deathmatch, AI, fog of war, minimap, group movement and simple UI. DAM work has added Android-compatible rendering/export, CI APK builds, touch camera pan/pinch zoom, touch unit selection/commands, and DAM identity.

## 4. Core game loop
1. Deploy/start with a command base.
2. Generate power and establish resource income.
3. Expand production and technology.
4. Scout while fog of war hides unexplored/enemy activity.
5. Counter the enemy's composition across land, air and sea.
6. Capture/contest strategic locations and resources.
7. Use faction powers and superweapons to break stalemates.
8. Win through mission objectives or destruction of key enemy infrastructure, depending on mode.

## 5. Factions
DAM targets **three original factions**, each with a complete technology tree and distinct economy/build mechanics.

### Faction A — Dominion
Heavy industrial doctrine: durable armor, direct firepower, strong defenses, slower deployment.

### Faction B — Vanguard
High mobility and precision: flexible vehicles, strong air power, rapid deployment and tactical abilities.

### Faction C — Eclipse
Asymmetric technology: stealth/deception, unusual movement and disruptive weapons, higher micro-management potential.

Names and lore are working concepts and can be refined, but the three-way asymmetry is a permanent design requirement.

## 6. Economy and base construction
Required systems:
- Credits/resources collected from contested resource fields/nodes.
- Harvesters or equivalent economy units.
- Refineries/drop-off structures.
- Power generation and power consumption.
- Low-power penalties.
- Placement grid/validity and build radius.
- Production queues.
- Repair and sell.
- Rally points.
- Technology prerequisites/tiers.
- Expansion bases/outposts.
- Visible build costs and build times.

The economy must reward expansion and map control rather than passive turtling.

## 7. Combat roster
Each faction ultimately needs equivalents for:
- Builder/MCV or deployment unit.
- Basic and specialist infantry.
- Anti-infantry, anti-armor and anti-air options.
- Scout/light vehicle.
- Main battle vehicle/tank.
- Artillery/siege.
- Transport.
- Harvester/economy unit.
- Fighter/interceptor.
- Ground-attack aircraft.
- Air transport/support.
- Naval scout.
- Main naval combatant.
- Anti-air naval unit.
- Long-range/heavy naval unit.
- Late-game signature unit.

Unit definitions should be data-driven: cost, HP, armor class, speed, weapons, range, targeting rules, production time, prerequisites and abilities.

## 8. Combat mechanics
- Projectile/hitscan weapon framework.
- Damage and armor classes.
- Turret/weapon rotation where appropriate.
- Target priorities and attack-move.
- Guard/hold/stop/patrol commands.
- Unit veterancy.
- Area damage and status effects.
- Active unit abilities with cooldowns.
- Formation-aware/group movement.
- Improved pathfinding and collision avoidance.
- Aircraft lifecycle/rearming where appropriate.
- Amphibious/naval movement support.

## 9. Touch controls
Touch interaction must feel native:
- One-finger camera pan.
- Pinch zoom.
- Tap to select.
- Drag selection where practical.
- Tap terrain to move selected units.
- Tap enemy to attack.
- Long-press/context action where useful.
- Double-tap/select-similar shortcut.
- Selection groups or mobile-friendly equivalent.
- Large, thumb-friendly command buttons.
- Cancel/back behavior that never causes accidental orders.
- Optional vibration/audio feedback.

Desktop mouse/keyboard support may remain for development, but must not dictate the Android UX.

## 10. Camera
- Smooth pan and zoom.
- Configurable zoom bounds.
- Edge/map bounds.
- Focus selected units.
- Jump via minimap.
- Optional camera rotation only if it improves touch play.
- Camera behavior must remain stable during multi-touch gestures.

## 11. Fog, vision and intelligence
- Proper unexplored/explored/currently-visible states.
- Per-unit/building sight radius.
- Enemy units hidden outside current vision.
- Last-known information only where deliberately designed.
- Detection/stealth framework for relevant faction mechanics.
- Minimap obeys fog and detection rules.

## 12. AI
Skirmish AI evolves in stages:
- Economy management.
- Base construction.
- Tech progression.
- Unit composition based on observed threats.
- Scouting.
- Defense response.
- Attack groups.
- Expansion/resource contesting.
- Ability/superweapon usage.
- Land/air/naval strategy.
- Multiple difficulty levels based primarily on decision quality, with optional explicit bonuses only if clearly configured.

## 13. Game modes
### Skirmish
Human vs AI and AI vs AI; configurable map, faction, teams and difficulty.

### Campaign
Three faction perspectives are the long-term target. Missions should support scripted objectives, triggers, reinforcements, dialogue, camera events, victory/failure conditions and save/checkpoint state.

### Additional modes
Team battles and objective scenarios can be added after the core skirmish game is stable. Multiplayer is a later milestone and must not block the single-player foundation.

## 14. Maps and environment
- Land, water and mixed maps.
- Resource placement and expansion zones.
- Strategic choke points plus alternate routes.
- Capturable neutral structures/locations.
- Destructible props where performance permits.
- Clear terrain readability on phone screens.
- Map metadata defining players, spawn points, resources and mission triggers.

## 15. Superweapons and faction powers
Each faction receives original strategic powers and at least one late-game superweapon. Systems need:
- Prerequisite structure/tech.
- Charge/cooldown state.
- Targeting mode.
- Clear warning/telegraph.
- Counterplay.
- AI support.
- Mobile-friendly activation UI.

## 16. UI/UX
Main menu:
- Continue/campaign.
- Skirmish.
- Settings.
- Credits.

In-match HUD:
- Resources.
- Power.
- Minimap.
- Production/build tabs.
- Selected unit/building information.
- Commands and abilities.
- Production queues.
- Objective display.
- Pause/settings.

The final HUD should be designed specifically for landscape Android screens and remain usable on tablets and phones.

## 17. Audio and presentation
- Original soundtrack direction.
- Faction-specific audio identity.
- Unit acknowledgements.
- Weapon/impact/explosion sounds.
- UI feedback.
- Ambient map audio.
- VFX for weapons, destruction, abilities and construction.
- Camera shake used sparingly.
- Intro/mission presentation can use in-engine cinematics rather than expensive pre-rendered video.

## 18. Save and progression
- Settings persistence.
- Campaign progress.
- Mission checkpoints where appropriate.
- Skirmish configuration persistence.
- Versioned save format to survive game updates.

## 19. Architecture
Keep gameplay systems modular. Prefer Resources/config data for unit/building definitions and avoid hard-coding individual content into controllers.

Target modules:
- Game/session manager.
- Player/faction state.
- Economy/power.
- Selection and command system.
- Unit/ability/weapon components.
- Building/construction/production.
- Navigation/movement.
- Vision/fog.
- AI.
- Mission scripting.
- Save system.
- Audio/VFX.
- Android input/UI.

New systems should expose clean interfaces/signals and be testable independently where practical.

## 20. Performance targets
DAM must be engineered for Android:
- Avoid per-frame work on every unit when event/tick-based logic is sufficient.
- Pool frequent projectiles/VFX where useful.
- Use LOD/culling and mobile-friendly materials.
- Batch expensive AI/pathfinding decisions.
- Profile CPU/GPU/memory on real Android builds.
- Establish scalable quality settings.
- Preserve responsive touch input under battle load.

A practical long-term target is smooth play during large battles on modern mid-range Android hardware; exact unit budgets will be established by profiling rather than guessed.

## 21. Development roadmap
### Phase 0 — Foundation (current)
Android export/CI, DAM identity, touch camera, touch selection and orders.

### Phase 1 — Mobile RTS vertical slice
Reliable touch controls, camera, selection, movement/attack, polished HUD, one complete economy loop, construction and production, one playable faction, one map, stable APK.

### Phase 2 — Combat foundation
Weapons/armor, abilities, veterancy, formations/pathfinding improvements, land/air/naval framework, VFX/audio baseline.

### Phase 3 — Three factions
Complete faction tech trees, differentiated construction/economy mechanics, unit rosters, powers and superweapons.

### Phase 4 — Skirmish
Map setup, improved AI, difficulty, victory conditions, multiple maps and full fog/minimap integration.

### Phase 5 — Campaign framework
Objectives/triggers, scripted events, dialogue, checkpoints, campaign progression and first polished missions.

### Phase 6 — Content and polish
More maps/missions, final UI, audio, effects, balancing, accessibility, tutorials and performance optimization.

### Phase 7 — Release candidate
Device testing, crash/error telemetry where appropriate, save migration, packaging, regression tests and signed release pipeline.

## 22. Immediate implementation order
Do not jump randomly between features. Next work should prioritize:
1. Verify the current Android touch-selection/command build.
2. Consolidate touch input so camera gestures and unit commands cannot conflict.
3. Implement the mobile HUD and selected-unit command panel.
4. Stabilize movement/attack commands and group behavior.
5. Upgrade construction, production, resource and power loops into the first vertical slice.
6. Build the first DAM faction end-to-end.
7. Profile the resulting APK before multiplying content.

## 23. Repository continuity rules
This document is the persistent source of truth for DAM.
- Continue from the existing repository and current implementation.
- Do not replace the project with a new repository/codebase unless explicitly decided.
- Before major implementation, read this document and current code/commits.
- Update this document when a major product/architecture decision changes.
- Keep the default branch buildable.
- Do not claim a feature works until its build/tests or relevant runtime behavior have actually been verified.
- Prefer small verified commits over large untested rewrites.
- Preserve Android as the primary target.
- GitHub Actions is the authoritative APK build path unless explicitly changed.

## 24. Definition of “full DAM”
DAM is considered feature-complete only when it has a polished Android control/UI layer; three complete asymmetric factions; economy, power, construction and tech trees; land, air and naval combat; abilities and superweapons; robust fog/minimap; competent skirmish AI; multiple maps; campaign framework/content; saves/settings; audio/VFX; and a reproducible stable APK build.

This vision is intentionally larger than the current prototype. Development should reach it through playable, testable milestones rather than attempting a single giant rewrite.

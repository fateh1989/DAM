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


## 2A. Real-world world map
DAM's long-term strategic space is one continuous real-world Earth map rather than a collection of unrelated fictional arenas. The geographic background is deliberately open and readable: terrain, coastlines, countries, borders, major cities and major roads remain visible. Any later enemy-intelligence or unit-visibility rules are separate from the visibility of the geographic map itself.

The first implementation milestone uses the Middle East as a bounded test region before expanding globally. The agreed prototype covers the connected region from Egypt and Turkey through the Levant and Gulf to Iran, Oman and Yemen, including Cyprus. Map content is streamed in tiles instead of loading the whole region into memory.

For the prototype, map detail is capped at **zoom 10**. Lower zoom levels remain available so the complete test region can be viewed at once; zoom 10 is the maximum detail level. The first implementation may use network-fetched OpenStreetMap raster tiles with visible attribution and an on-demand local cache only. It must not bulk-download the public OpenStreetMap tile service. The production architecture should later support a self-hosted or packaged tile source so DAM is not dependent on a public third-party tile server.

Geopolitical labels and boundary geometry must come from versioned source datasets rather than being manually redrawn in code. Disputed boundary presentation should preserve the source dataset's distinctions and provenance rather than inventing a DAM-specific political interpretation.

### Terrain foundation — implemented prototype
The first real-world terrain stage renders streamed **3D elevation geometry**, not a flat map viewer. Geographic positions are generated from WGS84 geodetic coordinates on the Earth ellipsoid, using real elevation values from Terrarium DEM tiles. Godot world units are kilometers so horizontal position and elevation use the same physical scale. The camera streams only nearby terrain chunks and supports map detail levels up to zoom 10. Roads, settlements, buildings, borders, land-cover and gameplay entities are separate later layers that must be placed on this same geospatial terrain rather than replacing it with a flat map.

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

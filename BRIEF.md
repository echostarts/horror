# PROJECT «ЭТАЖ 9» — VERTICAL SLICE BRIEF (Standing Instructions for Claude Code)

> **Заметка для оператора (Алексей):** это самостоятельная версия брифа под некоммерческий слайс — старый файл и override-блок не нужны. Положи этот документ как BRIEF.md в корень пустой папки, запусти Claude Code и скажи: *“Read BRIEF.md fully, then execute Section 13.”* Дальше — по майлстоунам из Section 10, сессия за сессией. Между сессиями проверяй CLAUDE.md и ASSET_MANIFEST.md. Твоя ручная работа здесь одна: скачивать ассеты по списку, который Claude Code будет вести в манифесте, и класть их в указанные папки.

-----

## 0. Your Role and Mission

You are the **lead programmer and technical artist** on a horror game vertical slice. I am the game director. You own all code, shaders, systems, architecture, audio integration, and the asset pipeline. I own creative direction and final taste calls.

**The mission:** a playable **10–15 minute slice** that is *indistinguishable in look, sound, and feel from a commercial release* in its niche. It will not be sold — but the quality bar is commercial. The test we are building toward: three screenshots and a 30-second gameplay clip that a stranger would assume came from a paid Steam game.

You work autonomously on implementation details. You stop only on [DECISION] triggers (Section 11).

-----

## 1. Product Definition

|Field             |Value                                                                                    |
|------------------|-----------------------------------------------------------------------------------------|
|Working title     |**«ЭТАЖ 9»**                                                                             |
|Genre             |First-person psychological horror, “anomaly loop” (Exit-8-like)                          |
|Engine            |Godot 4.x (latest stable, 4.4+), GDScript                                                |
|Target            |Windows desktop build, 60 fps on a mid-range laptop                                      |
|Slice length      |10–15 minutes, one ending                                                                |
|Language          |Russian UI only                                                                          |
|Comps (mechanics) |The Exit 8, I’m on Observation Duty                                                      |
|Comps (aesthetics)|ШХД: ЗИМА (panelka liminality), late-Soviet stairwells, VHS home video, PS1-era rendering|

**Premise.** 2:47 ночи. Девятиэтажная панелька. Лифт не работает. Ты поднимаешься по подъезду на свой девятый этаж. Пролёты повторяются. Правило простое: **заметил аномалию — спустись на пролёт вниз. Всё нормально — поднимайся.** Ошибка сбрасывает на первый этаж. И дом запоминает твои ошибки.

**Why this concept fits the mission:** one modular stairwell flight, ~40 props, zero animated characters. In this niche the “commercial look” is made of rendering, lighting, sound, and game feel — all code, all yours. The asset surface is deliberately tiny.

-----

## 2. Creative Pillars (tie-breakers for every decision)

1. **Dread over jumpscares.** The slice contains exactly **2** scripted hard scares; everything else is dread. Each scare must be earned by buildup.
1. **The ordinary made wrong.** Anomalies start at “wait, was that door number always 36?” before anything impossible appears.
1. **Sound is 60% of the game.** When visual and audio budgets conflict, audio wins.
1. **The player is never safe but rarely attacked.** Threat is presence. No health bar, no damage.
1. **Respect the loop.** Every anomaly must be fairly deducible in hindsight. Doubt is the goal; cheating is forbidden.

When pillars conflict, the lower number wins.

-----

## 3. Game Design Specification

### 3.1 Core Loop

- The stairwell is a procedurally sequenced chain of one modular flight (stairs + landing: two apartment doors, mailbox cluster, window, radiator, pipes, trash chute, lamp).
- On crossing a landing threshold, the Loop Manager evaluates the call:
  - Anomaly present + player went DOWN → correct → floor +1.
  - No anomaly + player went UP → correct → floor +1.
  - Otherwise → reset to floor 1, VHS tape-rewind transition, Tension penalty.
- **Delayed verdict:** the floor number stencil is revealed only at the *next* landing, after the call is committed. No instant right/wrong feedback — doubt is the core emotion.
- Reach floor 9 → ending sequence.
- The Loop Manager is a pure, unit-testable class: (anomaly_state, direction) → (advance | reset). No rendering logic inside.

### 3.2 Anomaly Framework

Each anomaly is a Godot Resource (.tres): id, display_name, category, tier (1–3), spawn_weight, min_tension, conflicts_with[], setup()/teardown() script ref, audio_cue (optional).

**Slice content: the 15 anomalies in Appendix A, exactly.** Categories represented: OBJECT, SPATIAL, LIGHT, TEXT, ENTITY, META (≥2 each). Tiers: T1 subtle (one detail), T2 unmistakable, T3 impossible/aggressive (gated to the final third of the slice).

The framework must be built so adding anomaly #16 is “new .tres + one script”, not engine surgery — the architecture is real even if the content list is short.

### 3.3 Escalation Director (lite)

A global autoload managing **Tension (0–100)**:

- Inputs: elapsed time, consecutive correct calls, mistakes, time frozen in place.
- Outputs: allowed anomaly tiers, ambience layer mix (Section 6), lamp behavior, the two scare slots, silence events.
- **Relief valves are mandatory:** after a T3 event or a reset, force ≥2 calm flights with ambience dropping a layer. Horror that never exhales becomes noise.
- **Silence as a weapon:** once or twice per run, hard-cut ALL ambience for 5–10 s before a T2/T3 spawn.
- Deterministic given a seed (QA repro). Real-time Tension graph in the debug overlay.

### 3.4 The Tenant («Жилец»)

**Never a character model.** Allowed representations only: a shadow occluder crossing a lit doorway; a peripheral-vision-only silhouette billboard that tears apart with VHS distortion when centered in view (>0.4 s gaze → dissolve + sting); positional sounds (wet barefoot steps, breathing behind door №40, knuckle taps one flight below); physical traces (a door slowly closing, a peephole going dark, prints on dusty steps). The slice’s finale beat: lamps die flight by flight below the player as they climb the last two floors — darkness rising. Light control + audio + FOV/shake only. Zero monster geometry.

### 3.5 Structure & Ending

- Floors 1→9, authored escalation curve, target 10–15 min for a first-timer.
- **One ending («Дом»):** the player reaches floor 9; their apartment door is ajar; the interior is a single static, perfectly mundane hallway shot — and the lamp behind them dies. Cut to title. Understatement over spectacle.
- Settings persist between launches. No run-save system — a run is 15 minutes.

-----

## 4. Technical Foundation

- **Godot 4.4+ stable**, GDScript with static typing everywhere.
- Renderer: Forward+. Gameplay rendered into a low-res SubViewport (default internal **640×360**; options 320×180 / 480×270 / 640×360), nearest-neighbor upscale.
- Autoloads (and nothing else): EventBus, GameState, Director, AudioDirector, SettingsService.
- Signals over polling; content is data (Resource files), no hardcoded anomalies in scripts; scene composition over inheritance.
- Folder structure: /src (systems), /scenes, /content/anomalies, /assets/{textures,models,audio,fonts}, /shaders, /ui, /tests, /docs.
- **GUT** unit tests for Loop Manager verdicts, Director math, anomaly selection, seed determinism.
- Debug overlay (F3): Tension graph, current anomaly id, floor state, seed. Compiled out of export builds.
- Performance: 60 fps at default internal res on integrated-GPU-class hardware; zero per-frame allocations in the hot path; pool AudioStreamPlayer3D nodes.
- Living documents you maintain every session: CLAUDE.md (state summary so a fresh session resumes cold), ARCHITECTURE.md, ASSET_MANIFEST.md, CHANGELOG.md.
- Git from minute one, conventional commits, tag every milestone.

-----

## 5. Visual Direction — the PS1/VHS Stack (all code; this IS the commercial look)

Implement as a layered, individually-toggleable stack:

1. **Low internal resolution** with nearest-neighbor upscale (Section 4).
1. **Vertex snapping + affine texture mapping** — global spatial shader (PSX vertex quantization in clip space; affine UVs). Snap strength exposed in settings.
1. **Ordered dithering + posterization** post (Bayer 4×4, ~5 bits/channel).
1. **Distance fog** — short, cold; the top of the next flight must always dissolve into uncertainty.
1. **VHS post layer:** scanlines, slight chroma bleed, tape-noise floor, tracking glitch. The tracking glitch is also a *system event* — the Director fires it on resets and Tenant proximity.
1. **Animated film grain** + vignette that breathes with Tension.
1. Optional CRT curvature toggle (off by default).

**Lighting:** one cold fluorescent fixture per landing; some dead; one per run flickering (flicker patterns are authored resources). No player flashlight — darkness is negotiated, not deleted. Real-time lights only where the Director needs control.

**Environment:** greybox the flight kit in CSG first (M1), swap to manifest-sourced modules/textures in M3. Prop budget ≤ 40 unique meshes.

**Brightness calibration screen** on first boot (“barely visible logo” pattern) — non-negotiable for a game this dark.

-----

## 6. Audio Direction (full scope — non-negotiable)

**Buses:** Master → Music, Ambience, SFX, UI. Long concrete reverb on a send bus (every positional SFX gets the tail). Stingers duck Ambience −6 dB, 0.8 s release.

**Systems:**

- **Footstep system first.** Surface-tagged (concrete / metal), ≥6 round-robin variations per surface, ±4% pitch jitter, synced to head-bob. Footsteps are the player’s metronome — perfect this before any other audio.
- **Breath layer** tied to Tension: inaudible at rest, ragged near T3.
- **3-layer ambience** crossfaded by Tension: L1 room tone + wind in the shaft; L2 building groans, pipe knocks, distant city; L3 sub-bass drone + air-pressure unease.
- **Positional one-shots** scheduled by the Director: a door slam two floors up, elevator cable ping, a chair dragged behind a door.
- **Tenant audio identity:** a unique drone + wet footsteps — the player learns to recognize it before ever “seeing” anything.
- All randomized SFX through one play_varied(pool, position) helper. No raw play() calls in gameplay code.

Procedural placeholder tones are fine during development (tagged PLACEHOLDER_), but **every sound in the finished slice is a real external file** per Section 7. Music for the slice: a dark-ambient menu drone + ending piece from a free pack is acceptable.

-----

## 7. Asset Strategy — relaxed licensing, same discipline

This is a non-commercial demo, so **any free-to-use license is acceptable, including CC-BY and CC-BY-NC.** Rules that still hold:

1. **You never fabricate an asset.** Missing file → engine-visible placeholder (magenta checker / labeled greybox / tagged beep) + a row in ASSET_MANIFEST.md. Never claim a file exists when it doesn’t.
1. **Every external asset gets a manifest row** (Appendix B schema) *before* integration, license included. Prefer CC0 when effort is equal — it keeps the commercial door open for later.
1. **You generate yourself:** procedural tileable textures via scripts (concrete, grunge, rust → PNG) as a base layer, all shaders, greybox geometry, UI.
1. **The manifest is also my shopping list.** For every slot, write the exact search query + suggested source so I can download in one pass. Suggested sources: itch.io free PSX-horror packs (e.g., DevilsWork.shop low-poly horror pack; “Eastern European Urban Decay” building pack; free PSX texture megapacks), ambientCG / Poly Haven (CC0 textures), Sonniss GameAudioGDC archives + freesound (SFX), free PSX-horror music packs on itch (music). Record the exact license per file when I deliver them.
1. **Fonts:** must cover Cyrillic; verify the license (prefer OFL) even now.

-----

## 8. Game-Feel / Juice Checklist (every item ships; tick off in CHANGELOG at M4)

**Camera & body:** head bob (toggle + amplitude) · landing dip entering each flight · breath sway scaling with Tension · FOV kick on sprint · micro-shake on stingers (≤0.3 s, capped) · subtle involuntary camera pull toward loud positional cues (cancellable).
**Movement:** acceleration/deceleration curves · stair-step smoothing (no capsule jitter) · footstep-to-bob sync · stamina with audible (not UI) feedback.
**Interaction:** diegetic only — handles visibly move; faint center dot that fades when idle; no floating world prompts (one subtitled hint on the first flight).
**Feedback:** floor-stencil reveal staged with light + a single piano-wire note · reset = VHS rewind (visual + audio) · correct-streaks subtly warm the lamp color (+150 K per step, reverts on mistake).
**UI:** zero HUD except subtitles + the center dot · menus styled as a VHS tape menu with hum and tracking jitter · one cohesive UI sound set.
**Clip-ability:** the slice must contain ≥3 moments that read perfectly in a 20-second vertical video with no context (the two scares + the darkness-rising finale). Mark them in the docs.

-----

## 9. UX Shell (minimal but polished)

- Pause anywhere. Main menu: Играть / Настройки / Выход — VHS aesthetic.
- Settings: внутренние разрешение, интенсивность VHS (0–100%), зерно, FOV 70–100, покачивание камеры, калибровка яркости (повторный запуск), режим фоточувствительности (отключает строб-класс мерцания — Director подставляет события без мерцания); громкость по шинам; чувствительность мыши, инверсия; gamepad works out of the box.
- All UI text in Russian. First boot: калибровка яркости → предупреждение (мерцающий свет / хоррор) → меню.

-----

## 10. Milestones (each ends with: tagged commit, updated docs, a “how to playtest” note for me)

**M0 — Foundation.** Repo, Godot project, folder tree, autoload skeletons, settings service, debug overlay, export preset working.
*DoD: I walk an empty greybox flight at 60 fps in a Windows build.*

**M1 — Vertical Slice Core.** Loop Manager (GUT-tested), greybox flight kit, movement controller with full camera feel, 6 anomalies (one per category), delayed-verdict flow, reset transition, temp audio wired through the final audio architecture.
*DoD: a stranger plays 10 minutes, understands the rule untold, and gets uneasy at least once. I playtest and gate this personally.*

**M2 — Content & Director.** All 15 anomalies from Appendix A, Director with relief valves + silence events, the two scare slots, ending sequence skeleton, seeded determinism.
*DoD: GUT green; a full 1→9 run is playable start to finish; the Tension graph matches the curve we agree on.*

**M3 — Visual Pass.** Full PS1/VHS stack, lighting design, manifest-sourced textures/modules integrated (I deliver files per your manifest shopping list), brightness calibration, photosensitivity mode.
*DoD: three screenshots pass the “stranger assumes it’s a paid Steam game” test.*

**M4 — Audio + Juice.** Section 6 complete with real files, Section 8 checklist 100%, the darkness-rising finale, ending fully staged.
*DoD: playable with eyes closed — the soundscape alone communicates floor, tension, and threat. A 30-second clip passes the stranger test. Project done.*

-----

## 11. Working Agreements

- **Session start ritual:** read CLAUDE.md + current milestone → post a short plan → execute. Never re-ask what this brief already decides.
- **[DECISION] triggers — stop and ask me:** anything that costs money; changes to pillars, the ending, or the title; scope additions >1 day; any asset whose license you can’t determine.
- **Never** fabricate assets, licenses, test results, or performance numbers. If you didn’t run it, say so.
- Boring, debuggable code over clever code — this project’s complexity lives in feel, not algorithms.
- Profile after every milestone; fix regressions before new features.

## 12. Out of Scope (do not build, do not propose)

Steam integration · achievements · saves mid-run · localization beyond Russian · multiple endings · Endless mode · multiplayer · VR · runtime LLM content · photorealism · health/combat · monetization of any kind.

## 13. Start Now

Execute **M0**. First print your M0 plan as a checklist, then proceed without waiting. When M0’s DoD is met, stop and give me playtest instructions.

-----

## Appendix A — The 15 Slice Anomalies (implement exactly these)

**OBJECT:** A1 лишняя пара обуви у двери №36 · A2 почтовый ящик открыт и переполнен одинаковыми письмами · A3 велосипед на площадке исчез — остался только закрытый замок.
**SPATIAL:** B1 тринадцать ступеней вместо двенадцати · B2 потолок ниже на ~15% · B3 дверь №34 заменена дублем №36.
**LIGHT:** C1 лампа горит тёплым вместо холодного · C2 мерцание в ритме сердцебиения · C3 свет пульсирует из-под одной двери.
**TEXT:** D1 граффити теперь читается «НЕ ПОДНИМАЙСЯ» · D2 трафарет этажа зеркальный.
**ENTITY:** E1 глазок двери темнеет, когда проходишь мимо · E2 силуэт пролётом выше уходит, когда на него смотришь · E3 мокрые босые следы — ведущие *вниз*.
**META:** F1 у шагов появляется эхо не в такт · F2 субтитр к звуку, которого не было.

Scare slot 1 (mid-run, Director-placed): E2 escalation — the silhouette is one landing closer than physics allows, single frame, VHS tear, hard sting. Scare slot 2: the finale’s first dead lamp directly behind the player with a breath at the neck (audio only).

## Appendix B — ASSET_MANIFEST.md Schema

One row per slot: slot_id | category (texture/model/sfx/music/font) | description | exact specs | status (placeholder → delivered → final) | suggested source + search query | license | notes.
Rules: row exists **before** integration; placeholders carry the PLACEHOLDER_ prefix; license = UNKNOWN is allowed during development but must be resolved before M4 sign-off.

*End of brief. Read fully before acting. When in doubt: Pillar 1, then ask.*

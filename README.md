# Drop The World

A satirical Plague-Inc-style sim where you spread your DJ career across the planet. Win by getting 95% of humanity to be a fan. Lose if the backlash meter hits 100 (you got cancelled).

Built in **Godot 4.6** with **GDScript**.

## Run it

1. Open Godot 4.6+
2. Import this folder as a project (`project.godot`)
3. Press **F5** (or the play button)

First run: pick a debut region. Then watch the spread.

## Controls

- **Space** — pause / unpause
- **1 / 2 / 3** — 1x / 2x / 4x speed
- Click trait buttons on the right to spend hype

## What's in this v0

- 15 regions (12 macro + North Korea + Antarctica + closed-region gimmick)
- Tick-based spread sim with neighbor bleed, climate bonuses, snowball growth, cold-start penalty
- Hype currency earned per million new fans
- Backlash meter that accrues passively once you're famous
- 5 traits: TikTok Dance, Masked Persona, Festival Circuit, Pirate Radio, Surprise Drop
- News ticker with ambient + backlash + milestone headlines pulled from `data/headlines.json`
- Win condition: 95% global fanbase. Lose condition: 100 backlash.

## Project layout

```
project.godot           — engine config (Main.tscn is the entry)
scenes/Main.tscn        — root scene: ticker + region list + HUD + debut modal
scripts/
  GameState.gd          — autoload singleton; hype, traits, tick driver
  SimTick.gd            — one tick of the spread simulation
  Region.gd             — region data class
  Main.gd               — scene controller, HUD, trait shop, input
  NewsTicker.gd         — scrolling marquee, ambient headlines
data/
  regions.json          — 15 region definitions (pop, resistance, climate, neighbors)
  headlines.json        — satirical ticker copy by category
icon.svg                — placeholder app icon
```

## What's intentionally missing in v0 (good next steps)

1. **Real map.** Regions are a vertical list, not a clickable world map. Drop in a free Mercator SVG and turn each region into a polygon button.
2. **Distribution channels.** Right now all spread is one undifferentiated curve. Add streaming / TikTok / radio / live / sync as channels that you toggle per region, each with its own cost and reach profile.
3. **Trait tree.** Five flat traits become a real tree (Sound → Persona → Marketing → Resilience), with prerequisites.
4. **Sound era system.** Lock you into a genre per "era"; switching genres costs hype and resets some region affinities.
5. **Audio.** Ironically there is none yet. A muffled four-on-the-floor under the ticker would sell the bit immediately.
6. **Save/load.** Godot makes this trivial — `ConfigFile` or JSON dump of GameState.
7. **Difficulty modifiers.** Industry Veteran / Mega modes that crank `culture_resistance` and `BACKLASH_FROM_FAME`.

## Tuning knobs

All in `scripts/SimTick.gd` constants and `GameState.TRAIT_CATALOG`:

- `BASE_GROWTH` — how fast a region adopts you per tick under neutral conditions
- `NEIGHBOR_WEIGHT` — how strongly fanbase in a neighbor pulls you up
- `HYPE_PER_FAN_MILLION` — hype economy throttle
- `BACKLASH_FROM_FAME` — how punishing global saturation is
- Per-region `culture_resistance` in `data/regions.json`

If the game feels too slow: bump `BASE_GROWTH` to 0.012 or `HYPE_PER_FAN_MILLION` to 2.0.
If you're winning trivially: raise `BACKLASH_FROM_FAME` to 0.08.

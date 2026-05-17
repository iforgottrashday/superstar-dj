# Khans  *(working title)*

A real-time medieval conquest sim. Pick a faction. Take Eurasia.

Built in **Godot 4.6** with **GDScript**. This repo started life as "Drop The World", a Plague-Inc-style superstar DJ sim — the conquest engine reuses ~70% of that codebase (map, tick loop, ticker, UI panels). Old game lives in git history.

## Run it

1. Open Godot 4.6+
2. Import this folder as a project (`project.godot`)
3. Press **F5**

You'll be shown a faction picker. Choose one, watch the map, and start ordering attacks.

## Playable factions

| Faction | Start | Attack | Defense | Production | Personality |
|---|---|---|---|---|---|
| **Mongol Horde** | Mongolia | +35% | -10% | +20% | Steppe cavalry. Massive offense, weak holding. Best for rapid expansion. |
| **Holy Roman Empire** | HRE | 0% | +30% | +10% | Heavy infantry, castles. Strong defense, slow offense. Surrounded. |
| **Byzantine Empire** | Byzantium | +10% | +25% | +15% | Greek fire, walled cities. Balanced. Three potential fronts. |
| **Mamluk Sultanate** | Egypt + Levant | +15% | +20% | +10% | Slave-soldier cavalry. All-rounder. Starts with two provinces. |
| **Song Dynasty** | China | 0% | +25% | +40% | Gunpowder pioneers. Production juggernaut. Hemmed in by the steppe. |

## How a tick works

1. **Recruit** — every owned region produces army based on `population × 0.05 × (1 + production_bonus)` per tick.
2. **AI factions act** — each non-player faction picks its best target ratio (its strongest stack vs an adjacent weakest enemy) and gambles on attacks if `random() < aggression`.
3. **Combat resolution** — when armies meet:
   - `attacker_strength = sent × (1 + atk_bonus) × random(0.88..1.12)`
   - `defender_strength = garrison × (1 + def_bonus) × (1.4 if fortified) × random(0.88..1.12)`
   - Attacker wins → region flips, survivors = `(atk - def) × 0.55`, fort destroyed in the siege
   - Defender wins → attackers wiped, defender weakened
4. **Income** — player gains `2 gold × regions owned` per tick passively, plus `+25` per conquered region.

## Controls

- **Click any region** — open the RegionPanel.
  - If it's yours → see adjacent enemies + a slider for how many troops to send.
  - If it's an enemy or neutral → see adjacent regions of yours that can launch an attack.
- **Space** — pause/unpause.
- **1 / 2 / 3** — 1x / 2x / 4x speed.

## Win / lose

- **Win**: control ≥ 70% of the 15 provinces (i.e. 11 regions).
- **Lose**: your last province is captured.

## Technology

Spend gold to research permanent buffs (Composite Bow, Castle Network, Trebuchet, Steppe Logistics, Greek Fire). Castle Network is a one-shot — it fortifies every region you currently own.

## Project layout

```
project.godot           — engine config
scenes/Main.tscn        — root scene: map + HUD + tech shop + modals
scripts/
  GameState.gd          — autoload singleton; factions, regions, treasury, tech
  SimTick.gd            — production + AI + combat resolution
  Region.gd             — region data class
  Main.gd               — scene controller, faction picker, attack flow, tech shop
  WorldMap.gd           — clickable Eurasian map, ownership-colored polygons
  NewsTicker.gd         — scrolling marquee, court chronicle
data/
  regions.json          — 15 medieval Eurasian provinces
  headlines.json        — court/battle/intrigue copy
icon.svg                — placeholder app icon
```

## Tuning knobs

In `scripts/SimTick.gd`:

- `BASE_RECRUIT_PER_POP` — production rate (default 0.05)
- `COMBAT_NOISE` — randomness in combat (default 0.12)
- `FORTIFIED_MULT` — defense multiplier for forts (default 1.40)
- `ATTACK_SEND_FRACTION` — what % of stack AI sends per attack (default 0.7)

In `scripts/GameState.gd` `FACTION_CATALOG`: each faction's `aggression` (0..1) gates how often it considers attacking per tick.

## What's missing in this v1

1. **Naval / sea crossings** — England, the Mediterranean, and the Sea of Japan are currently traversable as adjacent land. Real naval rules + transport ships are a future pass.
2. **Diplomacy** — alliances, vassalage, white peace, marriage pacts. Right now everyone is at war with everyone.
3. **Personality-driven AI** — currently AI is "send 70% of strongest stack at weakest target". Each faction's `aggression` is set but not flavored beyond probability gating.
4. **Save/load** — fresh game every launch.
5. **Audio** — nothing yet.
6. **More techs** — only 5 right now.
7. **Real Eurasia map shape** — polygons are rectangles. Easy upgrade.

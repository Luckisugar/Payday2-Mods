# Auto Skill Sets

[![SuperBLT](https://img.shields.io/badge/SuperBLT-required-blue.svg)](https://superblt.znix.xyz/)
[![PAYDAY 2](https://img.shields.io/badge/PAYDAY%202-mod-orange.svg)](https://store.steampowered.com/app/218620/PAYDAY_2/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Save your skill builds. Re-spend them after infamy. Keep extra-point skill sets and swap them freely.**

Going infamous wipes the equipped skill set on purpose. **Auto Skill Sets** remembers up to **8 builds**, spends points toward the active one as you level, and can keep other skill sets intact so you can swap back without wiping them.

This is a **Heist Helper** module.

---

## Features

| Feature | What it does |
|--------|----------------|
| **8 build slots** | Save / overwrite / delete snapshots of your skill tree |
| **Auto-spend** | When skill points land, spend them toward the active build |
| **Keep extra-point sets** | Swap to sets that spent more than your current budget. They are not wiped. Infamy still resets the equipped set. |
| **Skill points at 100** | Slider 120–300. Extra whole points are granted while you level 1–100 |
| **Bonus over vanilla** | Linked to the level-100 slider (`121` = bonus `1`) |
| **Mask skills from others** | Other players see vanilla skill totals for your level. Your real skills stay. Does not hide installed mods or in-heist effects. |
| **Infamy prompt** | Optional popup after a skill wipe |
| **Diff view** | Owned / partial / missing vs the active build |
| **SYSTEM chat** | Local notices only |
| **Mid-heist block** | Safety toggle — no auto-apply during heists by default |

---

## Requirements

- [SuperBLT](https://superblt.znix.xyz/)
- PAYDAY 2 (Steam)
- **Heist Helper** hub (included in the zip)

---

## Install

1. Install **SuperBLT** if you do not already have it.
2. Extract **both** folders into `PAYDAY 2/mods/`:
   - `HeistHelper`
   - `HH_AutoSkillSets`
3. Full restart PAYDAY 2.
4. Options → Mod Options → **Heist Helper → Auto Skill Sets**

If you already installed another Heist Helper pack, drop this zip in the same way. The hub stays; this module adds a new button.

---

## Quick start

1. Build your skills the way you like in-game.
2. Open **Heist Helper → Auto Skill Sets**.
3. Pick an **Active build slot**.
4. Click **Save current skills into slot**.
5. Leave **Auto-spend** on. **Keep extra-point skill sets** and **Mask skills from others** default on (rows live under **Edit (Cheat)**).

Keep a second vanilla skill set with your full build. After infamy, the equipped set resets; you can swap back to that second set immediately.

---

## Options overview

### Normal

- **Enabled** — master switch  
- **Auto-spend skill points** — spend on level-up toward the active slot  
- **Infamy restore prompt** — ask after skill wipe  
- **Block mid-heist apply** — safety default  
- **Active build slot** — which of 8 slots is live  
- **Save / Apply / Diff / Delete** — manage the active slot  

### Edit (Cheat)

Turn **Edit (Cheat)** on to show these rows (saved values still apply while hidden):

- **Keep extra-point skill sets** — swap without wiping over-budget sets  
- **Mask skills from others** — send vanilla-for-level totals in your outfit  
- **Skill points at level 100** / **Bonus over vanilla** — linked sliders (vanilla 120)  
- Level / Infamy / Skill Points / force-restore  

Raising the sliders tops up free points to what your current level should have. Lowering does **not** strip spent skills; you get a warning if a set already spent more than the new cap. Online risk is yours. Extra skills can still be visible in-heist even with masking on.

---

## How spending works

1. Skills are unlocked in **priority order**, then remaining skills in **tree / tier order**.
2. Tier unlock rules still apply (you cannot ace tier 4 before the tree allows it).
3. Extra points above 120 are granted as whole points spread across levels 1–100.
4. Every automatic or manual apply posts a short **SYSTEM** line when something changed.

Builds are stored in SuperBLT’s save path as `auto_skill_sets.txt` (survives mod folder updates).

---

## Links

- **Repo:** https://github.com/Luckisugar/Payday2-Mods  

---

## License

MIT — see [LICENSE](LICENSE).

Made by **Luckysugar** / [Luckisugar](https://github.com/Luckisugar).

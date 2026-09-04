# Auto Skill Sets

[![SuperBLT](https://img.shields.io/badge/SuperBLT-required-blue.svg)](https://superblt.znix.xyz/)
[![PAYDAY 2](https://img.shields.io/badge/PAYDAY%202-mod-orange.svg)](https://store.steampowered.com/app/218620/PAYDAY_2/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/Luckisugar/AutoSkillSets?include_prereleases)](https://github.com/Luckisugar/AutoSkillSets/releases)

**Save your skill builds. Re-spend them automatically after infamy and level-ups.**

Going infamous wipes your skills on purpose. If you always rebuild the same set, that grind gets old fast. **Auto Skill Sets** remembers up to **8 builds**, spends points toward the active one as you level, and can fully restore a build when you want.

---

## Features

| Feature | What it does |
|--------|----------------|
| **8 build slots** | Save / overwrite / delete named snapshots of your skill tree |
| **Auto-spend** | When skill points land, spend them toward the active build |
| **Priority order** | Rebuild follows saved priority (tier-safe multi-pass) |
| **Infamy prompt** | Optional popup: **Yes** · **No** · **Restore Skills (Cheat)** |
| **Diff view** | Owned / partial / missing vs the active build |
| **SYSTEM chat** | Local notices only (not public lobby spam) |
| **Edit (Cheat)** | Optional Level / Infamy / Skill Points controls |
| **Mid-heist block** | Safety toggle — no auto-apply during heists by default |

---

## Requirements

- [SuperBLT](https://superblt.znix.xyz/)
- PAYDAY 2 (Steam)

---

## Install

1. Install **SuperBLT** if you do not already have it.
2. Download the latest release zip **or** clone this repo.
3. Copy the `AutoSkillSets` folder into:

   `PAYDAY 2/mods/AutoSkillSets`

4. Launch the game. Options appear under **Options → Mod Options → Auto Skill Sets**.

---

## Quick start

1. Build your skills the way you like in-game.
2. Open **Mod Options → Auto Skill Sets**.
3. Pick an **Active build slot**.
4. Click **Save current skills into slot**.
5. Leave **Auto-spend** and **Infamy restore prompt** on (recommended).

After infamy, pick **Yes** to re-spend with real points, or **Restore Skills (Cheat)** for a full force-restore.

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

Enable **Edit (Cheat)** first, then use:

- **Level** + Apply  
- **Infamy** + Apply  
- **Skill Points** + Apply  
- **Restore Skills (Cheat)** — complete the saved build without enough free points  

Cheats can trip skill-point detectors and look bad online. Use at your own risk.

---

## How spending works

1. Skills are unlocked in **priority order**, then remaining skills in **tree / tier order**.
2. Tier unlock rules still apply (you cannot ace tier 4 before the tree allows it).
3. The apply loop multi-passes until nothing else can be unlocked with current points (or until cheat fills the rest).
4. Every automatic or manual apply posts a short **SYSTEM** line when something changed.

Builds are stored in SuperBLT’s save path as `auto_skill_sets.txt` (survives mod folder updates).

---

## Links

- **Repo:** https://github.com/Luckisugar/AutoSkillSets  
- **Other PD2 mods:** https://github.com/Luckisugar/Payday2-Mods  

---

## License

MIT — see [LICENSE](LICENSE).

Made by **Luckysugar** / [Luckisugar](https://github.com/Luckisugar).

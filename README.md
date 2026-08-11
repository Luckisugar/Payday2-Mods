# Payday 2 Mods (Luckisugar)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Game](https://img.shields.io/badge/game-PAYDAY%202-yellow)](#)
[![Loader](https://img.shields.io/badge/loader-SuperBLT-orange)](#)

Personal SuperBLT mods for **PAYDAY 2**. Client-side QoL / stealth tooling. Not affiliated with Starbreeze or Overkill.

---

## Table of contents

- [Install](#install)
- [Mods](#mods)
  - [Big Ammo Pickups](#1-big-ammo-pickups)
  - [Omniscience+](#2-omniscience)
  - [Saw Stealth Conceal](#3-saw-stealth-conceal)
  - [Silent Assassin (fork)](#4-silent-assassin-fork)
  - [Auto Skill Sets](#5-auto-skill-sets)
  - [Instant Heists](#6-instant-heists)
  - [Loot Mule](#7-loot-mule)
- [Notes](#notes)
- [License](#license)

## Install

1. Install **[SuperBLT](https://superblt.znix.xyz/)** if you do not already have it.  
2. Copy each mod **folder** into:

   `…\Steam\steamapps\common\PAYDAY 2\mods\`

3. Full restart PAYDAY 2.  
4. Configure under **Options → Mod Options**.

## Mods

### 1) Big Ammo Pickups

Buffs ammo from the small boxes enemies drop.

- Multiplier (default **10×**)
- Optional min/max floors
- Optional boost for zero-pickup weapons (RPG, saw, bows, etc.)
- Fully Loaded / Walk-in Closet still stack on top

### 2) Omniscience+

Buffs **Sixth Sense** stealth radar (stand-still).

- Faster sense delay, longer range
- Marks guards (and optional cameras / items) with real contours
- Local-only by default; optional team sync
- Independent of VanillaHUD’s sense hooks where possible

### 3) Saw Stealth Conceal

Raises **OVE9000 Saw** concealment for stealth builds (default **30**).

- Slider in Mod Options  
- Primary + secondary saw tweak entries  

### 4) Silent Assassin (fork)

Based on **Silent Assassin** by **DrTachyon** (pager / stealth-kill rules).

**Luckysugar additions** (defaults **on**):

| Option | Effect |
|--------|--------|
| **Only My Kills** | No-pager stealth kill applies only to **your** kills (best when you host) |
| **Only While Crouching** | No-pager only if the killer is **crouching** |

Original SA options (pager counts, detection threshold, matchmaking filter) still work.

> Host authority: pager removal is decided on the **server**. Host this mod for reliable behavior.

### 5) Auto Skill Sets

Saves skill builds and re-spends them after **infamy** / level-ups so you are not rebuilding the same tree by hand every time.

- **8 slots** — save / overwrite / delete snapshots of your skill tree  
- **Auto-spend** — spend free skill points toward the active build on level-up  
- **Infamy prompt** — optional **Yes** / **No** / **Restore Skills (Cheat)**  
- **Diff view** — owned / partial / missing vs the active build  
- **SYSTEM chat** — local notices only when the mod spends or applies  
- **Edit (Cheat)** — optional Level / Infamy / Skill Points controls  
- Mid-heist auto-apply **blocked by default**

> Cheat restore / Edit (Cheat) can trip skill-point detectors and look bad online. Use at your own risk.

### 6) Instant Heists

Full **cheat** mod: skip equipment gates and speed up waits.

- **Bypass requirements** — keycards, shaped charges, ECM, cook chemicals, crowbars, etc.  
- **Consume if owned** — if you already have the required item, it is still consumed; if you do not, the interact works anyway  
- **Timer speed** — drills, vault/hack GUIs, mission timers, element delays (van, cook loops, staged waits)  
- Global speed multiplier (default **5×**, slider 1–20)  
- Options under **Mod Options → Instant Heists**

> Host for reliable mission timers. Pure client-only lobbies will not always speed host-side scripts. This is an obvious cheat — expect desync / lobby drama online.

**v1.1.0:** optional **Only while crouching** — bypass + timer cheats only apply when ducked.

### 7) Loot Mule

Carry **as many bags as you want** (stack, last in / first out). Not Carry Stacker — original Luckysugar mod.

- **Crouch to pick up** (default on) — throwing works standing  
- **Throw distance** slider (0.25×–10×, default 1×)  
- Stack count hint on pickup  
- Body bags stack too  
- Options under **Mod Options → Loot Mule**

> Throw distance scales best when you host (or solo). Obvious multi-bag cheat online.

## Notes

- These are **mods**, not cheats aimed at public matchmaking advantage. Use common sense online.  
- Silent Assassin updates from the original author may overwrite a Vortex install — keep this fork folder if you want the crouch / local options.  
- Auto Skill Sets stores builds in SuperBLT’s save path (`auto_skill_sets.txt`), not only inside the mod folder.  
- Instant Heists settings save to `instant_heists.txt` in the SuperBLT save path.  
- Loot Mule settings save to `loot_mule.txt` in the SuperBLT save path.  
- Game Lua dumps for research: [Payday-2-LuaJIT-Complete](https://github.com/steam-test1/Payday-2-LuaJIT-Complete) (reference only).

## License

MIT for **original Luckisugar code** (Big Ammo, Omniscience+, Saw Stealth Conceal, Auto Skill Sets, Instant Heists, Loot Mule).

Silent Assassin remains credit to **DrTachyon**; this repo ships a small fork with extra options. If the original license differs, treat that folder under the original author’s terms and contact them for redistribution questions.

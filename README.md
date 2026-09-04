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
  - [Ninja](#4-ninja)
  - [Auto Skill Sets](#5-auto-skill-sets)
  - [Instant Heists](#6-instant-heists)
  - [Loot Mule](#7-loot-mule)
  - [Instant Restart](#8-instant-restart)
  - [Ally Spectate](#9-ally-spectate)
  - [Diamond Path Helper](#10-diamond-path-helper)
  - [Meth Helper](#11-meth-helper)
- [Notes](#notes)
- [License](#license)

## Install

1. Install **[SuperBLT](https://superblt.znix.xyz/)** (64-bit / Diesel 3.0).  
2. Copy **`HeistHelper`** (the hub) plus any **`HH_*`** module folders into:

   `…\Steam\steamapps\common\PAYDAY 2\mods\`

   Nexus zips already contain both. Installing a second pack only adds another `HH_*` folder; overwriting `HeistHelper` is safe.

3. Full restart PAYDAY 2.  
4. Configure under **Options → Mod Options → Heist Helper**.

## Mods

### 1) Big Ammo Pickups

Buffs ammo from the small boxes enemies drop.

- Multiplier (default **10×**)
- Optional min/max floors
- Optional boost for zero-pickup weapons (RPG, saw, bows, etc.)
- Fully Loaded / Walk-in Closet still stack on top
- Optional **Fill magazine from reserve** — boxes chamber the mag (vanilla reload clip write). Works at max ammo, including RPG / missile.

### 2) Omniscience+

Buffs **Sixth Sense** stealth radar (stand still to pulse).

- Faster sense delay, longer range
- Marks spawned guards, cameras, pickups, crates, safes, loose/baggable loot, ATMs
- Per-category checkboxes under Mod Options (computers / body bags / dropped bags default **off**)
- Circuit boxes: closed panels you can actually open this run (dummy spawn slots stay hidden)
- Contour first; HUD icon only if a silhouette cannot be applied
- Cameras: outline only, no HUD icons; outline stays up between pulses
- Local-only by default; optional team sync

### 3) Saw Stealth Conceal

Raises **OVE9000 Saw** concealment for stealth builds (default **30**).

- Slider in Mod Options  
- Primary + secondary saw tweak entries  

### 4) Ninja

Based on **Silent Assassin** by **DrTachyon** (pager / stealth-kill rules).

**Luckysugar additions** (defaults **on**):

| Option | Effect |
|--------|--------|
| **Only My Kills** | No-pager stealth kill applies only to **your** kills (best when you host) |
| **Only While Crouching** | No-pager only if the killer is **crouching** |

Original SA options (pager counts, detection threshold) still work. Crime.net lobby filter is gone — Ninja does not touch matchmaking.

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
- **Protect puzzle / path timers** (default **ON**) — never speed **The Diamond** floor-tile path lifetime (or its circuit-box clock). Without this, 5× speed expires the safe path before you walk it → wrong-tile alarm while Diamond Path Helper is still correct.  
- **Ghost Mode** — 100% undetectable to guards/cameras (toggle under options).  
- Options under **Mod Options → Instant Heists**

> Host for reliable mission timers. Pure client-only lobbies will not always speed host-side scripts. This is an obvious cheat — expect desync / lobby drama online.

**v1.1.0:** optional **Only while crouching** — bypass + timer cheats only apply when ducked.  
**v1.1.1:** fixed crash planting free shaped charges / mission-door deployables with none owned.  
**v1.1.2:** **Speed mission script delays** option (default off) so Bain/radio reminder VO does not spam; drills/vaults still speed under the main timer toggle.  
**v1.1.3:** VHUD+ compat — pagers/dangerous holds stay vanilla; hold-to-interact scaling clamps so auto-hold + drop-bag cancel still works.  
**v1.2.0:** protect The Diamond path/puzzle timers from speed; **Ghost Mode** (undetectable).  
**v1.2.1:** real path fix — ElementTimer is logic, DigitalGui is display; on mus **deny-all ElementTimer speed** except time-lock whitelist; linked DigitalGui inherits the same mult (fixes UI 90s / door at 5s desync and first-tile wrong-path alarms).

### 7) Loot Mule

Carry **as many bags as you want** (stack, last in / first out). Not Carry Stacker — original Luckysugar mod.

- **First bag standing**; **crouch to stack more** (default on) — throw always works standing  
- **Throw distance** slider (0.25×–10×, default **1.69**, step **0.01**)  
- **Dump entire stack on throw** (default on) — one G = pile dump; off = LIFO one bag  
- Stack count HUD + optional **Notifications** (pickup/drop hint; off = silent)  
- **Unlimited body bags** default on; bag anti-cheat bypass so stacks are not eaten  
- Options under **Mod Options → Loot Mule**  
- **v1.0.4:** dump-all option + throw default 1.69

> Throw distance scales best when you host (or solo). Obvious multi-bag cheat online.

### 8) Instant Restart

**Host hotkey** to restart the current heist, **rebuy last preplan + mission assets**, and **auto-start past briefing** into map load.

- Not Esc → Restart / FishTaco (those only dump you on briefing)  
- Bind: **Options → Mod Keybinds** → **Instant Restart (reload heist)**  
- **Rebuy** snapshots what you bought to disk before restart, then:  
  - **Preplanning heists** — stock rebuy path (+ force-reserve if soft-blocked)  
  - **Mission-asset heists** (e.g. Nightclub) — re-unlock last asset IDs, else **Buy All Assets**  
- **SYSTEM chat** announcements (not under your Steam name); peers with this mod get SYSTEM too  
- Safety: host-only, peer synched/outfit/streaming checks, cooldown, pcall guards, auto-start timeout  
- **Does not skip map loading**  
- Settings: `instant_restart.txt` · debug log: `instant_restart.log` · asset snapshot: `instant_restart_assets.json`  

> Host only. Blocked while a peer is still loading (reduces blackscreens).

### 9) Ally Spectate

Live **through-their-eyes** camera on your teammates while you are still alive.

- Hotkeys: **Ally 1 / Ally 2 / Ally 3**, **Return to me**, **Next ally**  
- Bind under **Options → Mod Keybinds**  
- Same-slot key again returns to yourself  
- Freezes local movement while watching (optional, default on)  
- Includes bots (optional)  
- Auto-exits on damage / down / tase  
- Client-side only — your body still sits in the world  

> Other players are third-person husks on your client, so this tracks **head position + look direction** (not their exact FPS hands).

### 10) Diamond Path Helper

Prints the **real** safe floor-tile path for **The Diamond** after the chamber path box is hacked (not the buggy light guide).

- Private / public / both chat
- Numbered 6×9 grid: rows **1–9** (entrance → diamond), columns **1–6** left → right
- Fixed-width cells: `##` = safe, `--` = alarm (columns do not shift)
- **+15s** on the path lifetime (30s → 45s on DW/DS). Host only. Toggle under options.
- Settings: `diamond_path_helper.txt`

> Host for the extra 15 seconds. Chat path still works as a client.

**v1.3.0:** +15s path timer; numbered `--`/`##` grid; no S/E/D markers.

### 11) Meth Helper

Bain/Locke cook lines as ingredient callouts. Based on **Meth Helper Updated** (Offyerrocker).

- Toggle under Heist Helper → Meth Helper
- Optional keybind to mute callouts mid-heist

## Notes

- These are **mods**, not cheats aimed at public matchmaking advantage. Use common sense online.  
- Silent Assassin updates from the original author may overwrite a Vortex install — keep this fork folder if you want the crouch / local options.  
- Auto Skill Sets stores builds in SuperBLT’s save path (`auto_skill_sets.txt`), not only inside the mod folder.  
- Instant Heists settings save to `instant_heists.txt` in the SuperBLT save path.  
- Loot Mule settings save to `loot_mule.txt` in the SuperBLT save path.  
- Instant Restart settings save to `instant_restart.txt` in the SuperBLT save path.  
- Ally Spectate settings save to `ally_spectate.txt` in the SuperBLT save path.  
- Game Lua dumps for research: [Payday-2-LuaJIT-Complete](https://github.com/steam-test1/Payday-2-LuaJIT-Complete) (reference only).

## License

MIT for **original Luckisugar code** (Heist Helper hub, Big Ammo, Omniscience+, Saw Stealth Conceal, Auto Skill Sets, Instant Heists, Loot Mule, Instant Restart, Ally Spectate, Diamond Path Helper).

Ninja remains credit to **DrTachyon** (Silent Assassin fork) with Luckysugar options. Meth Helper cook lines credit **Offyerrocker**. If an original license differs, treat that folder under the original author’s terms.

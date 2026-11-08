# FEFW Custom Build

A performance-tuned build of **Fortune's Eden**, the Eden emulator fork for *Fire Emblem: Fortune's Weave*, based on the v1.4.2 source of [TheSneakyBadger/FEFW-Stable-with-60-FPS-Patch](https://github.com/TheSneakyBadger/FEFW-Stable-with-60-FPS-Patch).

Every change here was measured on real hardware with frame-time logs, the emulator's own back-thread statistics, and a Windows Performance Recorder CPU profile taken in Dagsion's crowds.

> **Legal use only.** This repository and its releases contain no games, keys, firmware or other Nintendo files. Use your own legally obtained copy of the game, with keys and firmware dumped from your own console. Not affiliated with, endorsed by or sponsored by Nintendo or NVIDIA.

## Download

Get **`FEFW-Custom-Build-v1.1.zip`** from **[Releases](../../releases)**.

**v1.1** removes v1.0's Dagsion sky fix. It kept GPU-drawn images in video memory permanently, which filled VRAM in long sessions. v1.1 uses the upstream v1.4.2 texture cache behaviour: in a 20-minute test on an RTX 4060 Ti, VRAM stayed at 7.8–8.5 GB (v1.0 reached ~16 GB).

**Requirements:**
- 64-bit Windows 10/11
- A Vulkan GPU
- **A CPU with AVX2**: Intel 4th gen Core (Haswell) / AMD Ryzen or newer
- 16 GB RAM plus a large page file (system managed or about 32 GB). The game needs the 12 GB memory layout, and a small page file causes crashes.

## Install

1. Extract the zip to a new folder (not inside Program Files).
2. Coming from another Fortune's Eden build? Copy your old `user` folder into the new folder. It holds your saves, keys, firmware, settings and shader cache.
3. Start the game with `Launch FEFW Fast.bat` (included in the zip). It runs the emulator at high priority. `Launch Diagnostic.bat` also logs performance statistics.

## What changed compared with the v1.4.2 source

| Change | Why | Switch |
|---|---|---|
| `EDEN_CPU_WRITE_PAGES` defaults to **1** (was 16) | 16 caused recurring stutter: held CPU writes reached the GPU a batch late ([upstream issue #2](https://github.com/TheSneakyBadger/FEFW-Stable-with-60-FPS-Patch/issues/2)) | `EDEN_CPU_WRITE_PAGES=N` |
| GPU-modified page bitmap in front of `IsRegionGpuModified` | ~730k checks/s in crowds, 99% answer "no" | `EDEN_NO_PAGE_FILTER=1` turns it off |
| Cache flushing before each draw locks the query and shader caches once per batch, and skips them when empty | ~55k flush batches/s × ~4 ranges, each locking twice | — |
| Descriptor sets are compared where they sit in the descriptor ring instead of copying ~70 KB per set draw | Only ~3% of set draws ever compared the copy | — |
| Optional lock-free answer for held CPU writes | Game threads waited ~1.1 s/s on the buffer cache lock in crowds | **Off by default**, `EDEN_FAST_HOLD=1` |
| Statistics: share of texture-table rebuilds matching one of the last 4 builds | Tested a caching idea (result: 0%, dropped) | `EDEN_BACK_THREAD_STATS=1` |
| Release build: **PGO trained on Dagsion crowds** and compiled with **`/arch:AVX2`** | | — |

Exact code changes: [`patches/fefw-custom-changes.patch`](patches/fefw-custom-changes.patch). Full modified source: [`eden-fefw-1.12/`](eden-fefw-1.12).

**Not included from upstream v1.5** (its source was not published when this was built): the Dagsion sky fix, the ultrawide option, the CPU Clocks removal, the smaller logs and the version label in the title.

## Results (i5-10400F, RTX 4060 Ti 16 GB, 16 GB RAM, Dagsion's busiest crowd)

| Build | Crowd FPS | Typical frame | Worst 1% | Notes |
|---|---|---|---|---|
| Upstream v1.4.2 (stutter fix via `.bat`) | 25.3 | 38.8 ms | 58.7 ms | Longest freeze 138 ms |
| **This build** | ~25 | ~40 ms | ~47–52 ms | Even frames; GPU back thread 8.7 → 8.2 µs per draw |
| This build + `EDEN_FAST_HOLD=1` | 28.2 | 33.5 ms | 54.5 ms | Higher average, but noticeably uneven |

Outside crowds the game holds a steady 30 FPS (its native frame rate). See [`docs/RESULTS.md`](docs/RESULTS.md) for the measurements and the profiling findings.

**Why crowds stay around 25 FPS:** a big crowd issues ~70,000 draws per second. One emulator thread (the GPU "back thread") translates them all, and in crowds it is 84–90% busy. Meanwhile the game's own CPU threads queue on the caches' locks. Making either side faster mostly moves the limit to the other side. The remaining options are a faster CPU (single-core speed matters most) or a large redesign of the emulator's GPU threading.

## Recommended settings

- Resolution **1x**, GPU accuracy **Fast**, asynchronous shaders **on**, VRAM Usage Mode **Conservative**, VSync **off**
- Anti-aliasing **SMAA** or none, anisotropic filtering **16x**, window filter **Area** when the output is larger than your monitor
- NVIDIA DLSS: off if you get crashes in the NVIDIA driver (`nvoglv64.dll`)
- Weaker PCs (e.g. 4th-gen i5 + GTX 1070): **Handheld mode** (renders ~1080p instead of 4K), DLSS off. For a smoother look, use frame generation from the [Lossless Scaling](https://store.steampowered.com/app/993090/Lossless_Scaling/) app (LSFG 2x, windowed or borderless). It looks smoother but still responds at the base frame rate.

## Diagnostics

`launchers/Launch Diagnostic.bat` sets `EDEN_BACK_THREAD_STATS=1`. Every 4 seconds the emulator writes back-thread, lock and draw statistics to `user\log\eden_log.txt`. This build also logs one line per frame, so frame times can be measured from the log.

## Building from source

Requirements:
- Visual Studio Build Tools 2026 with "Desktop development with C++" (MSVC 19.51), including CMake and Ninja
- [Vulkan SDK](https://vulkan.lunarg.com/) (for `glslangValidator`)
- Git
- About 30 GB free

The build downloads its libraries (Qt, FFmpeg, Boost, SDL and others) automatically.

```powershell
# from the repo root, with the Vulkan SDK's Bin folder on PATH
Set-ExecutionPolicy -Scope Process Bypass
.\Build-Local-MSVC.ps1 -Version 1.12 -Portable -Pgo Train -Avx2   # instrumented build
# play the training build (FEFW-PGO-Training) in busy areas, close it normally,
# move the eden!N.pgc files into pgo-fefw\, then:
.\Build-Local-MSVC.ps1 -Version 1.12 -Portable -Pgo Use -Avx2     # optimised build + zip
```

Drop `-Avx2` for a build that runs on any x64 CPU. Add `-Symbols` for a build with `eden.pdb` for profiling. The PGO profile used for the v1.0 release is attached to the release as `pgo-profile.zip` (extract it to `pgo-fefw\`). It only matches this exact source and compiler.

## Credits

- [TheSneakyBadger](https://github.com/TheSneakyBadger/FEFW-Stable-with-60-FPS-Patch): Fortune's Eden, the base of this build, and its detailed optimisation notes in `eden-fefw-1.12/docs`
- xDarkWindx (eden-fefw), Duck912 (eden-ns2-fe, DLSS work in Eglantine), the Eglantine and PokeDinner contributors
- The Eden and yuzu emulator projects

## Licence

GPL-3.0-or-later, the same as the upstream project. See [LICENSE](LICENSE).

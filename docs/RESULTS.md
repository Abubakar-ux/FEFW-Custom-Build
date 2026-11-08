# Measurements and findings

Test PC: Intel i5-10400F (6 cores/12 threads), RTX 4060 Ti 16 GB, 16 GB RAM, 36 GB page file, Windows 11, NVIDIA 581.42.

Scene: Dagsion's busiest crowd. Settings: 1x, docked, DLSS off, SMAA, VRAM Conservative.

Frame times come from the per-frame `QueueNativeImage` log lines. Back-thread numbers come from `EDEN_BACK_THREAD_STATS=1`.

## Frame times in the crowd

| Run | Avg FPS | p50 | p90 | p99 | Max |
|---|---|---|---|---|---|
| Upstream v1.4.2, `EDEN_CPU_WRITE_PAGES=1` | 25.3 | 38.8 ms | 45.7 ms | 58.7 ms | 138 ms |
| PGO + AVX2 + page filter + sky fix | 25.6 | 39.5 ms | 42.3 ms | 47.0 ms | 50 ms |
| Same, `EDEN_CPU_WRITE_PAGES=4` | 27.0 | 36.1 ms | 43.6 ms | 47.4 ms | 52 ms |
| + lock batching + in-place descriptor compare (v1.0, stats on) | 24.7 | 40.6 ms | 48.4 ms | 51.7 ms | 59 ms |
| v1.0 + `EDEN_FAST_HOLD=1` (stats on) | 28.2 | 33.5 ms | 43.8 ms | 54.5 ms | 62 ms |

`EDEN_CPU_WRITE_PAGES=4` and `EDEN_FAST_HOLD=1` both raise the average frame rate but felt stuttery or jittery in play. The first holds CPU writes from GPU-visible pages longer. The second lets the game run ahead, so held writes are applied in batches about 5x larger. Both stay off by default.

## GPU back thread (stats on, crowd)

| | Before | v1.0 |
|---|---|---|
| Draws/s | ~67,900 | ~68,700 |
| Busy | 85.2% | 83.5% |
| Prepare draw | 8.70 µs/draw | **8.21 µs/draw (−5.6%)** |
| Descriptor compare | 2.0% | < 1% |
| Flush caching | 6.0% | 5.5% |

## Locks (stats on, crowd)

- Game threads called `OnCPUWrite` ~120–160k times/s and waited **~1.1 s/s** in total on `buffer_cache.mutex`. 89% of those calls answered "held" (the page is GPU-modified).
- `EDEN_FAST_HOLD=1` answers all held writes without the lock: waiting dropped to ~0.48 s/s. But the back thread then rose to 90–92% busy, and frame pacing became uneven.

## Ideas tested and dropped

- **Caching several texture tables per descriptor:** 0.0% of ~3,000–3,900 table rebuilds/s matched any of the table's last 4 builds. Crowd tables really change.
- **Skipping the front thread's `Drain` on semaphore acquires:** a CPU profile (WPR) showed much of the kernel time is the front GPU thread sleeping and waking around ~1,000 drains/s. The upstream notes (`docs/back-thread-split-plan.md`, experiment D) show the acquires wait for native compute QMD completion on the GPU, which the front thread cannot predict. Skipping was tried upstream and removed.

## Conclusion

In big crowds the limit is shared between the GPU back thread (~70k draws/s on one thread) and the game's CPU threads contending for the cache locks. Further gains need a faster CPU (single-core speed) or a redesign of the emulator's GPU threading.

## v1.1: long-session check

v1.0's Dagsion sky fix kept every small GPU-drawn image that could not be copied back to guest memory. In this game many render targets are like that, so in a 32-minute v1.0 session they filled the RTX 4060 Ti's 16 GB of VRAM at 19 minutes (`heap0 usage=15935 MiB budget=15341 MiB`). The driver then placed new buffers in system RAM (`CheckPlacement` warnings), and from about 26 minutes on, frames over 50 ms rose to 160–210 per 2 minutes.

v1.1 removes that fix (the upstream v1.4.2 texture cache). In a 20-minute session there were no `CheckPlacement` warnings and dedicated GPU memory stayed at 7.8–8.5 GB. Frame times after loading: 29.1 FPS average, p50 33.4 ms, p90 34.7 ms, p99 49.5 ms.

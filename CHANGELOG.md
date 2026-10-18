# Changes in the RISC OS port of VCMI

## 1.7.5-riscos1test (not released)
First test build: VCMI 1.7.5 for RISC OS 5, not yet run on RISC OS.
- One static program: the game, its server (in a thread) and the computer
  players (Nullkiller, Nullkiller2, BattleAI, StupidAI). No launcher, map
  editor, films, online play or HD Edition graphics.
- RISC OS platform support: directories (<VCMI$Dir>, <VCMI$Data>,
  <Choices$Write>.VCMI), output to VCMI$Log, error boxes, heap in 128 MB
  dynamic areas, no console thread, the working directory left alone.
- A stand-in for oneTBB (riscos/tbb): serial loops, real threads for the
  computer players' tasks (tests/tbbshim).
- Presenting only what changed, with the pointer blended in, straight into
  the window surface (tests/present); the frame limiter waits in
  Wimp_PollIdle; RISC OS defaults (software renderer, 50 fps, no vsync,
  no xBRZ, nearest scaling, no intro).
- Libraries: Boost 1.83 (with a RISC OS statfs patch), minizip (zlib
  1.3.1), SDL2_image 2.6.3, SDL2_ttf 2.20.2, SDL2_mixer 2.6.3, riscos-mesa
  devkit 20.3.5-16 (SDL2, zlib), riscos-crossdev 1.8.2 (toolchain 1.4).

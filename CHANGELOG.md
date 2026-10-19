# Changes in the RISC OS port of VCMI

## GOG Import 1.0 (2026-10-19)
- !GOGImport: gets Data, Maps and Mp3 out of the GOG.com installer of
  Heroes III Complete on RISC OS. Drag the installer's .exe or -1.bin onto
  its icon or window, drag !VCMI or a directory in to choose where the files
  go (default !VCMI.H3data), click Import. innoextract runs in a TaskWindow,
  so the desktop keeps running; progress, the result and any problem show in
  the window, not in an error box.
- innoextract 1.9 for RISC OS (static; bzip2 1.0.8, liblzma 5.8.1, Boost
  1.83; its heap in a dynamic area).
- Tested in RISC OS for Linux (testbed 0.9): the GOG Complete installer
  (77075) unpacked to 225 files, identical to innoextract on Linux; dragging
  the window and opening the icon bar menu during the import; a bad
  installer reports "Not a supported Inno Setup installer!".

## 1.7.5-riscos2test (2026-10-19, not released)
- The computer players are Nullkiller2 / BattleAI again: the static AI table
  picks them by library name (libNullkiller2), and the RISC OS directories
  gave no "lib", so every computer player was EmptyAI (ends its turn at once).
- No sound modules (SharedSoundBuffer, StreamManager) no longer stops the
  game: sound and game controllers are optional, the game plays silently.
- Mixer chunks of 4096 samples (1024 underran in other ports).
- Tested in RISC OS for Linux (riscos-linux-testbed 0.9, desktop, its patched
  UnixLib, GOG Heroes III Complete data): main menu, scenario list, a game of
  "Arrogance" for a week (8 days) against three Nullkiller2 players (0.5-6 s
  a turn, mostly 1-2 s), autosaves, 50 fps with about 1% of the screen
  redrawn a frame.

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
- CStopWatch in milliseconds: UnixLib's clock() counts centiseconds, so
  VCMI's CLOCKS_PER_SEC / 1000 was 0 (a division by zero at start-up).
- Two random map templates named "...200%" are "...200pc" (% can't be in
  a RISC OS file name).
- Started in RISC OS for Linux (riscos-linux-testbed 0.9, no game data):
  loads its config and built-in mod, writes its settings, and stops with
  "VCMI requires Heroes III ... data files", as it should.
- Libraries: Boost 1.83 (with a RISC OS statfs patch), minizip (zlib
  1.3.1), SDL2_image 2.6.3, SDL2_ttf 2.20.2, SDL2_mixer 2.6.3, riscos-mesa
  devkit 20.3.5-16 (SDL2, zlib), riscos-crossdev 1.8.2 (toolchain 1.4).

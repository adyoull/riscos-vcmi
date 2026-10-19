# Changes in the RISC OS port of VCMI

## 1.7.5-riscos5test (not released)
- Sound without SDL's audio thread. SDL2_mixer mixes on request
  (patches/sdl2_mixer/0002: Mix_OpenAudioExternal, Mix_MixAudioExternal) and
  riscos/riscos_sound.cpp hands its 23 ms blocks straight to
  SharedSoundBuffer, keeping about 190 ms queued (was about 370 ms). The queue
  is topped up from whichever thread is running: every frame and between the
  frame limiter's waits, the loading loop, every network pack the client and
  the server handle, the AI's parallel_for loops (the TBB stand-in now runs a
  blocked_range in up to 16 pieces with the hook between them), and a feeding
  thread of its own. A thread inside the mixer (a decoder reading its file)
  skips it.
- The log keeps info and above by default (it was trace: about 170 lines a
  second, mostly network packs, each written to the card).
- The frame limiter waits in steps of at most a centisecond, so 30 fps no
  longer comes out at 20-25.
- The vcmilog now has the presenter's figures ("Present:") and, in the
  "Frames:" line, who fed the sound, the least queued and how often it ran
  dry.

## 1.7.5-riscos4test (not released)
- The sound stopped for up to 1.4 s when a hero moved onto another terrain
  (the riscos3test log: sound gaps of 0.2-1.4 s, matching the longest
  frames). VCMI resumes each terrain's music where it left off, and dr_mp3,
  without a seek table, seeks by decoding the MP3 from the start to that
  point while holding the audio lock. SDL2_mixer now gives dr_mp3 a seek
  table when the music is loaded (patches/sdl2_mixer/0001): on Linux, seeking
  100 s into GRASS.MP3 went from 75 ms to 0.2 ms, the table taking 2 ms.

## 1.7.5-riscos3test (not released)
- Sound stuttered while a hero moved (Pi, full screen). SDL's sound thread
  only runs when UnixLib's ticker switches to it; the frame limiter now
  gives the other threads a turn every frame.
- 30 frames a second by default (50 before; `video.targetfps` in
  settings.json changes it).
- The log (test builds, VCMI$Log) has a line every 10 s: frames, time spent
  drawing and waiting, sound blocks mixed and the longest gap between them.
- Hot paths (profiled on Linux with a hero walking across the map):
  - the fog-of-war check made for every tile on screen and its neighbours
    every frame looked the player's team up each time; it is now kept, and
    a frame's map drawing takes about a sixth less work (patch 0014);
  - the presenter converts each logical row once (NEON where the processor
    has it) and then only stretches it, instead of converting every screen
    pixel through the scale table (patch 0015).

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

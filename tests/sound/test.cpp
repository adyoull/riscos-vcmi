// Host test of riscos/riscos_sound.cpp (SDL_mixer fed from any thread into a
// simulated SharedSoundBuffer that plays in real time), with the SDL2_mixer
// built from patches/sdl2_mixer.
#include "riscos_sound.h"

#include <SDL.h>
#include <SDL_mixer.h>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <thread>
#include <vector>

static int failures = 0;
#define CHECK(c, ...) do { if(!(c)) { std::printf("FAIL: " __VA_ARGS__); std::printf("\n"); failures++; } } while(0)

static std::atomic<int> postmixCalls{0};

int main()
{
	SDL_Init(0);
	std::string why;
	CHECK(riscos::soundStart(why), "soundStart: %s", why.c_str());
	// a looping square wave, as a sound effect
	std::vector<Sint16> wave(44100 * 2);
	for(size_t i = 0; i < wave.size(); i++)
		wave[i] = ((i / 40) & 1) ? 6000 : -6000;
	Mix_Chunk * chunk = Mix_QuickLoad_RAW(reinterpret_cast<Uint8 *>(wave.data()), static_cast<Uint32>(wave.size() * 2));
	CHECK(chunk, "chunk");
	Mix_PlayChannel(-1, chunk, -1);
	// polling from inside the mixer (as a decoder reading its file would)
	// must neither deadlock nor mix
	Mix_SetPostMix([](void *, Uint8 *, int) { postmixCalls++; riscos::soundPoll(); riscos::soundPump(); }, nullptr);

	// 1. the feeding thread alone keeps the queue filled
	std::this_thread::sleep_for(std::chrono::milliseconds(1500));
	auto s = riscos::soundStats();
	std::printf("thread only: %d blocks (%d by the thread), %d dry, least queued %d ms\n", s.blocks, s.byThread, s.dry, s.minQueuedMs);
	CHECK(s.blocks >= 60 && s.blocks <= 75, "about 1.5 s of blocks (65), got %d", s.blocks);
	CHECK(s.dry == 0, "ran dry %d times", s.dry);
	CHECK(postmixCalls > 0, "postmix ran");

	// 2. many threads polling while the main thread plays and halts sounds
	std::atomic<bool> stop{false};
	std::vector<std::thread> pollers;
	for(int t = 0; t < 4; t++)
		pollers.emplace_back([&, t] { while(!stop) { riscos::soundPollFrom(t == 0 ? riscos::SoundCaller::Frame : riscos::SoundCaller::Other); std::this_thread::sleep_for(std::chrono::milliseconds(1 + t)); } });
	auto end = std::chrono::steady_clock::now() + std::chrono::milliseconds(2000);
	int plays = 0;
	while(std::chrono::steady_clock::now() < end)
	{
		int ch = Mix_PlayChannel(-1, chunk, 0);
		if(plays++ % 2)
			Mix_HaltChannel(ch);
		Mix_Volume(-1, plays & 127);
		std::this_thread::sleep_for(std::chrono::milliseconds(3));
	}
	stop = true;
	for(auto & t : pollers)
		t.join();
	s = riscos::soundStats();
	std::printf("polling from 5 threads: %d blocks (frame %d, thread %d, other %d), %d dry, least queued %d ms, %d plays\n",
		s.blocks, s.byFrame, s.byThread, s.byOther, s.dry, s.minQueuedMs, plays);
	CHECK(s.blocks >= 80 && s.blocks <= 95, "about 2 s of blocks (86), got %d", s.blocks);
	CHECK(s.dry == 0, "ran dry %d times", s.dry);
	CHECK(s.byFrame + s.byOther > 0, "the polling threads fed some");

	riscos::soundStop();
	Mix_FreeChunk(chunk);
	riscos::soundPoll(); // after stopping: nothing
	SDL_Quit();
	std::printf(failures ? "FAIL (%d)\n" : "PASS\n", failures);
	return failures != 0;
}

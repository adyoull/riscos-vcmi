// Host test of riscos/riscos_present.cpp (the RISC OS presenter).
// Random frames, scales and pointer moves: after every frame the target
// surface must equal a reference made the simple way (the whole screen
// scaled nearest-neighbour, the pointer blended over it), and only pixels in
// the reported rectangles may have changed.
#include "riscos_present.h"

#include <SDL.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <vector>

static int failures = 0;

static uint32_t blendRef(uint32_t a, uint32_t b)
{
	uint32_t alpha = a >> 24, inv = 255 - alpha;
	if(alpha == 255) return a;
	if(alpha == 0) return b;
	uint32_t out = 0;
	for(int sh = 0; sh <= 16; sh += 8)
	{
		uint32_t ca = (a >> sh) & 0xff, cb = (b >> sh) & 0xff;
		out |= (((ca * alpha + cb * inv + 0x80) >> 8) & 0xff) << sh;
	}
	return out;
}

static uint32_t pix(SDL_Surface * s, int x, int y)
{
	return reinterpret_cast<uint32_t *>(static_cast<uint8_t *>(s->pixels) + y * s->pitch)[x];
}

struct Ptr { SDL_Surface * img; int x, y; bool shown; };

static void reference(SDL_Surface * ref, SDL_Surface * screen, const Ptr & ptr, bool swap)
{
	for(int dy = 0; dy < ref->h; dy++)
		for(int dx = 0; dx < ref->w; dx++)
		{
			int sx = static_cast<int>(static_cast<int64_t>(dx) * screen->w / ref->w);
			int sy = static_cast<int>(static_cast<int64_t>(dy) * screen->h / ref->h);
			uint32_t c = pix(screen, sx, sy);
			if(ptr.shown && sx >= ptr.x && sx < ptr.x + ptr.img->w && sy >= ptr.y && sy < ptr.y + ptr.img->h)
				c = blendRef(pix(ptr.img, sx - ptr.x, sy - ptr.y), c);
			c &= 0xffffff;
			if(swap)
				c = (c & 0xff00) | (c >> 16) | ((c & 0xff) << 16);
			reinterpret_cast<uint32_t *>(static_cast<uint8_t *>(ref->pixels) + dy * ref->pitch)[dx] = c;
		}
}

static void randomFill(SDL_Surface * s, std::mt19937 & rng, int changes)
{
	for(int i = 0; i < changes; i++)
	{
		int w = 1 + rng() % 120, h = 1 + rng() % 60;
		int x = static_cast<int>(rng() % s->w), y = static_cast<int>(rng() % s->h);
		uint32_t c = rng();
		for(int yy = y; yy < std::min(y + h, s->h); yy++)
			for(int xx = x; xx < std::min(x + w, s->w); xx++)
				reinterpret_cast<uint32_t *>(static_cast<uint8_t *>(s->pixels) + yy * s->pitch)[xx] = (rng() % 4 == 0) ? rng() : c;
	}
}

static void runCase(int sw, int sh, int dw, int dh, bool swap, unsigned seed)
{
	std::mt19937 rng(seed);
	SDL_Surface * screen = SDL_CreateRGBSurfaceWithFormat(0, sw, sh, 32, SDL_PIXELFORMAT_ARGB8888);
	SDL_Surface * target = SDL_CreateRGBSurfaceWithFormat(0, dw, dh, 32, swap ? SDL_PIXELFORMAT_XBGR8888 : SDL_PIXELFORMAT_XRGB8888);
	SDL_Surface * ref = SDL_CreateRGBSurfaceWithFormat(0, dw, dh, 32, SDL_PIXELFORMAT_XRGB8888);
	SDL_Surface * before = SDL_CreateRGBSurfaceWithFormat(0, dw, dh, 32, target->format->format);
	SDL_Surface * img = SDL_CreateRGBSurfaceWithFormat(0, 24 + rng() % 20, 24 + rng() % 20, 32, SDL_PIXELFORMAT_ARGB8888);
	randomFill(screen, rng, 200);
	for(int y = 0; y < img->h; y++)
		for(int x = 0; x < img->w; x++)
		{
			uint32_t a = (x + y) % 5 == 0 ? 0 : (x % 3 == 0 ? 255 : rng() % 256);
			reinterpret_cast<uint32_t *>(static_cast<uint8_t *>(img->pixels) + y * img->pitch)[x] = (a << 24) | (rng() & 0xffffff);
		}
	riscos::presentReset();
	Ptr ptr{img, sw / 2, sh / 2, true};
	int frameFailures = 0;
	for(int frame = 0; frame < 60 && !frameFailures; frame++)
	{
		int what = static_cast<int>(rng() % 6);
		if(what == 0) { /* nothing changes */ }
		else if(what == 1) ptr.x += static_cast<int>(rng() % 9) - 4, ptr.y += static_cast<int>(rng() % 9) - 4;
		else if(what == 2) ptr.x = static_cast<int>(rng() % (sw + 40)) - 20, ptr.y = static_cast<int>(rng() % (sh + 40)) - 20; // also partly outside
		else if(what == 3) ptr.shown = !ptr.shown;
		else if(what == 4) reinterpret_cast<uint32_t *>(img->pixels)[rng() % (img->w)] ^= 0xff00ffff; // pointer image changes
		else randomFill(screen, rng, 1 + rng() % 6);
		riscos::presentSetPointer(ptr.shown ? img : nullptr, ptr.x, ptr.y);
		std::memcpy(before->pixels, target->pixels, static_cast<size_t>(target->pitch) * dh); // raw copy, no conversion
		std::vector<SDL_Rect> rects = riscos::presentToSurface(target, screen);
		reference(ref, screen, ptr, swap);
		for(int y = 0; y < dh && !frameFailures; y++)
			for(int x = 0; x < dw; x++)
			{
				uint32_t got = pix(target, x, y), want = pix(ref, x, y);
				if(got != want)
				{
					std::printf("FAIL %dx%d->%dx%d swap %d seed %u frame %d: (%d,%d) %08x want %08x\n", sw, sh, dw, dh, swap, seed, frame, x, y, got, want);
					frameFailures++;
					break;
				}
				if(frame > 0 && pix(before, x, y) != got)
				{
					bool inside = false;
					for(auto & r : rects)
						inside = inside || (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h);
					if(!inside)
					{
						std::printf("FAIL %dx%d->%dx%d seed %u frame %d: (%d,%d) changed outside the rectangles\n", sw, sh, dw, dh, seed, frame, x, y);
						frameFailures++;
						break;
					}
				}
			}
	}
	failures += frameFailures;
	SDL_FreeSurface(screen); SDL_FreeSurface(target); SDL_FreeSurface(ref); SDL_FreeSurface(before); SDL_FreeSurface(img);
}

int main()
{
	struct { int sw, sh, dw, dh; } sizes[] = {
		{800, 600, 800, 600},     // 1:1
		{800, 600, 1600, 1200},   // 200%
		{1280, 800, 1920, 1200},  // 150%
		{1000, 625, 1920, 1200},  // 192%
		{853, 533, 1280, 800},    // odd sizes, partial cells
		{1920, 1200, 1280, 800},  // smaller than the logical size
	};
	unsigned seed = 1;
	for(auto & s : sizes)
		for(int swap = 0; swap < 2; swap++)
			for(int run = 0; run < 3; run++)
				runCase(s.sw, s.sh, s.dw, s.dh, swap, seed++);
	std::printf("%s (%d failures)\n", failures ? "FAILED" : "PASS", failures);
	return failures ? 1 : 0;
}

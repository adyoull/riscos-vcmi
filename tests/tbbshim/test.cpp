// Host test of riscos/tbb (the oneTBB stand-in). Built twice by run.sh:
// with ThreadSanitizer and with AddressSanitizer + UBSan.
#include <tbb/parallel_for.h>
#include <tbb/parallel_reduce.h>
#include <tbb/parallel_invoke.h>
#include <tbb/blocked_range2d.h>
#include <tbb/task_group.h>
#include <tbb/task_arena.h>
#include <tbb/global_control.h>
#include <tbb/concurrent_hash_map.h>
#include <tbb/concurrent_vector.h>
#include <tbb/concurrent_queue.h>
#include <tbb/concurrent_unordered_set.h>
#include <tbb/concurrent_unordered_map.h>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <future>
#include <string>
#include <thread>
#include <vector>

static int failures = 0;
#define CHECK(c) do { if(!(c)) { std::printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); ++failures; } } while(0)

struct StrHash {
	static std::size_t hash(const std::string & s) { return std::hash<std::string>()(s); }
	static bool equal(const std::string & a, const std::string & b) { return a == b; }
};

// VCMI's lib/AsyncRunner.h, as it uses the arena and group.
class AsyncRunner {
	tbb::task_arena arena;
	tbb::task_group taskGroup;
	tbb::global_control control;
	static int size() { return std::max(tbb::this_task_arena::max_concurrency(), 4); }
public:
	AsyncRunner() : arena(size()), control(tbb::global_control::max_allowed_parallelism, size()) {}
	template<typename F> void run(F && f) { arena.enqueue(taskGroup.defer(std::forward<F>(f))); }
	void wait() { taskGroup.wait(); }
	~AsyncRunner() { wait(); }
};

// the RISC OS progress hook (riscos/riscos_progress.h), counted
static int progressCalls = 0;
extern "C" void riscos_progress_hook(void) { progressCalls++; }

static void loops()
{
	std::vector<int> v(1000, 0);
	tbb::parallel_for(tbb::blocked_range<size_t>(0, v.size()), [&](const tbb::blocked_range<size_t> & r) {
		for(size_t i = r.begin(); i != r.end(); ++i) v[i] += 1;
	});
	tbb::parallel_for(0, 1000, [&](int i) { v[i] += 1; });
	bool all2 = true;
	for(int x : v) all2 = all2 && x == 2;
	CHECK(all2);
	int calls = 0;
	tbb::parallel_for(tbb::blocked_range<size_t>(5, 5), [&](const tbb::blocked_range<size_t> &) { ++calls; });
	CHECK(calls == 0);  // empty range: body not called

	// pieces: every index exactly once, at most 16 pieces, none below the
	// grain size (but the last), the progress hook between pieces
	for(size_t n : {1u, 2u, 15u, 16u, 17u, 100u, 1000u, 12345u})
		for(size_t g : {1u, 3u, 10u, 2000u})
		{
			std::vector<int> seen(n, 0);
			int pieces = 0, small = 0;
			int before = progressCalls;
			tbb::parallel_for(tbb::blocked_range<size_t>(0, n, g), [&](const tbb::blocked_range<size_t> & r) {
				pieces++;
				if(r.size() < g && r.end() != n) small++;
				for(size_t i = r.begin(); i != r.end(); ++i) seen[i]++;
			});
			bool once = true;
			for(int x : seen) once = once && x == 1;
			CHECK(once);
			CHECK(pieces >= 1 && pieces <= 16);
			CHECK(small == 0);
			CHECK(progressCalls - before == pieces);
		}
	{
		int before = progressCalls;
		tbb::parallel_for(0, 640, [&](int) {});
		CHECK(progressCalls - before == 10); // every 64th index
	}

	int cells = 0;
	tbb::parallel_for(tbb::blocked_range2d<int>(0, 7, 2, 0, 9, 2), [&](const tbb::blocked_range2d<int> & r) {
		for(int y = r.rows().begin(); y < r.rows().end(); ++y)
			for(int x = r.cols().begin(); x < r.cols().end(); ++x) ++cells;
	});
	CHECK(cells == 63);

	int maxY = tbb::parallel_reduce(tbb::blocked_range<int>(0, 50), -1,
		[](const tbb::blocked_range<int> & r, int m) { for(int i = r.begin(); i < r.end(); ++i) if(i % 7 == 0) m = std::max(m, i); return m; },
		[](int a, int b) { return std::max(a, b); });
	CHECK(maxY == 49);
	CHECK(tbb::parallel_reduce(tbb::blocked_range<int>(3, 3), 42,
		[](const tbb::blocked_range<int> &, int) { return 0; }, [](int a, int) { return a; }) == 42);

	int a = 0, b = 0;
	tbb::parallel_invoke([&] { a = 1; }, [&] { b = 2; });
	CHECK(a == 1 && b == 2);
	CHECK(tbb::this_task_arena::current_thread_index() == 0);
}

// Four tasks that each wait until all four have started: needs 4 workers at once.
static void blockingWorkers()
{
	std::mutex m; std::condition_variable cv; int started = 0;
	std::atomic<int> done{0};
	{
		AsyncRunner runner;
		for(int i = 0; i < 4; ++i)
			runner.run([&] {
				std::unique_lock l(m);
				++started; cv.notify_all();
				bool ok = cv.wait_for(l, std::chrono::seconds(10), [&] { return started == 4; });
				if(ok) ++done;
			});
		runner.wait();
	}
	CHECK(done == 4);
}

// A task that waits for a task queued after it (VCMI's AI does this): with a
// fixed pool of 4 already busy, the fifth must still run.
static void moreBlockedThanWorkers()
{
	std::promise<void> fifth; auto f = fifth.get_future().share();
	std::atomic<int> done{0};
	AsyncRunner runner;
	for(int i = 0; i < 4; ++i)
		runner.run([&, f] { if(f.wait_for(std::chrono::seconds(10)) == std::future_status::ready) ++done; });
	runner.run([&] { fifth.set_value(); ++done; });
	runner.wait();
	CHECK(done == 5);
}

// wait() can be called while tasks submit more tasks (re-entrant, as AsyncRunner says).
static void nestedSubmit()
{
	std::atomic<int> n{0};
	AsyncRunner runner;
	for(int i = 0; i < 8; ++i)
		runner.run([&] { ++n; runner.run([&] { ++n; }); });
	runner.wait();
	CHECK(n == 16);
}

static void hashMap()
{
	using Map = tbb::concurrent_hash_map<std::string, std::pair<int, int>, StrHash>;
	Map map;
	std::vector<std::thread> ts;
	for(int t = 0; t < 8; ++t)
		ts.emplace_back([&, t] {
			for(int i = 0; i < 2000; ++i) {
				std::string key = "k" + std::to_string(i % 50);
				Map::accessor acc;
				if(map.find(acc, key)) acc->second.first += 1;
				else { acc.release(); map.emplace(key, std::pair<int, int>{1, t}); }
				Map::const_accessor cacc;
				if(map.find(cacc, key)) (void)cacc->second.second;
			}
		});
	for(auto & t : ts) t.join();
	CHECK(map.size() == 50);
	long total = 0;
	for(auto & kv : map) total += kv.second.first;
	// a lost race between find and emplace drops one count; not more than one per key per thread
	CHECK(total > 16000 - 50 * 8 && total <= 16000);

	Map::accessor acc;
	CHECK(map.insert(acc, std::string("new")));      // created
	acc->second = {7, 7};
	acc.release();
	CHECK(!map.insert(acc, std::string("new")));     // already there
	CHECK(acc->second.first == 7);
	CHECK(map.erase(acc));                            // erase through an accessor
	CHECK(acc.empty());
	CHECK(map.count("new") == 0);
	Map::const_accessor c;
	CHECK(!map.find(c, "missing") && c.empty());
	CHECK(map.insert(Map::value_type("v", {1, 2})) && !map.insert(Map::value_type("v", {3, 4})));
	Map copy = map;
	CHECK(copy.size() == map.size());
}

static void containers()
{
	tbb::concurrent_vector<int> v;
	tbb::concurrent_unordered_set<int> s;
	tbb::concurrent_unordered_map<int, int> um;
	tbb::concurrent_queue<std::unique_ptr<int>> q;
	std::vector<std::thread> ts;
	for(int t = 0; t < 8; ++t)
		ts.emplace_back([&, t] {
			for(int i = 0; i < 500; ++i) {
				v.push_back(i); v.emplace_back(-i);
				s.insert(i % 100);
				um.emplace(t * 1000 + i, i);
				q.push(std::make_unique<int>(i));
			}
		});
	for(auto & t : ts) t.join();
	CHECK(v.size() == 8000);
	CHECK(s.size() == 100 && s.count(42) == 1);
	CHECK(um.size() == 4000 && um.at(7005) == 5);
	int popped = 0; std::unique_ptr<int> p;
	while(q.try_pop(p)) ++popped;
	CHECK(popped == 4000 && q.empty());
	v.clear(); CHECK(v.empty());
}

int main()
{
	loops();
	blockingWorkers();
	moreBlockedThanWorkers();
	nestedSubmit();
	hashMap();
	containers();
	std::printf("%s (%d failures)\n", failures ? "FAILED" : "PASS", failures);
	return failures ? 1 : 0;
}

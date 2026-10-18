// Boost.Config doesn't know RISC OS: tell it what UnixLib provides.
#define BOOST_HAS_UNISTD_H
#define BOOST_HAS_GETTIMEOFDAY
#define BOOST_HAS_NANOSLEEP
#define BOOST_HAS_CLOCK_GETTIME
#define BOOST_HAS_PTHREADS
#define BOOST_HAS_SCHED_YIELD
#define BOOST_HAS_DIRENT_H
// No dladdr or backtrace in UnixLib: stack traces are empty.
#define BOOST_STACKTRACE_USE_NOOP

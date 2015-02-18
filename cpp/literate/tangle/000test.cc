typedef void (*test_fn)(void);

const test_fn Tests[] = {
  #include "test_list"  // auto-generated; see makefile
};

bool Passed = true;

long Num_failures = 0;

#define CHECK(X) \
  if (!(X)) { \
    ++Num_failures; \
    cerr << "\nF " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): " << #X << '\n'; \
    Passed = false; \
    return; \
  }

#define CHECK_EQ(X, Y) \
  if ((X) != (Y)) { \
    ++Num_failures; \
    cerr << "\nF " << __FUNCTION__ << "(" << __FILE__ << ":" << __LINE__ << "): " << #X << " == " << #Y << '\n'; \
    cerr << "  got " << (X) << '\n';  /* BEWARE: multiple eval */ \
    Passed = false; \
    return; \
  }

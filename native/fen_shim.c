// native/fen_shim.c
#include <stdint.h>
#include <stdlib.h>
#include <string.h>   // memcpy

// Pull in the implementation from the header
#define FENSTER_IMPLEMENTATION
#include "fenster.h"

struct fen_handle { struct fenster f; };

#ifdef _WIN32
  #define FEN_API __declspec(dllexport)
#else
  #define FEN_API
#endif

FEN_API void* fen_open(int width, int height, const char* title, uint32_t* buf) {
  // Build a fully-initialized handle on the stack (legal for const members)
  const struct fen_handle init = {
    .f = { .title = title, .width = width, .height = height, .buf = buf }
  };

  // Allocate the real handle and copy the bytes in one shot
  struct fen_handle* h = (struct fen_handle*)malloc(sizeof *h);
  if (!h) return NULL;
  memcpy(h, &init, sizeof init);

  if (fenster_open(&h->f) < 0) { free(h); return NULL; }
  return h;
}

FEN_API int  fen_loop (void* handle) { return fenster_loop(&((struct fen_handle*)handle)->f); }
FEN_API void fen_close(void* handle)  { struct fen_handle* h = (struct fen_handle*)handle; fenster_close(&h->f); free(h); }

FEN_API int  fen_key  (void* handle, int code) {
  if (code < 0 || code > 255) return 0;
  return ((struct fen_handle*)handle)->f.keys[code];
}

FEN_API void      fen_sleep(int ms) { fenster_sleep(ms); }
FEN_API long long fen_time()        { return fenster_time(); }

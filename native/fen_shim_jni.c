#include <jni.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "fenster.h"
#include "fenster_audio.h"
#include "demo_FenShim.h"

// ----- window handle -----
struct fen_handle {
  struct fenster f;
  char *title_copy;
};

// ----- audio handle -----
struct aud_handle {
  struct fenster_audio fa;
};

// ----- helpers -----
static struct fen_handle* fen_from(jlong p) { return (struct fen_handle*)(intptr_t)p; }
static struct aud_handle* aud_from(jlong p) { return (struct aud_handle*)(intptr_t)p; }

// Let the JVM know this library is JNI-ready (since we export it).
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
  (void)vm; (void)reserved;
  return JNI_VERSION_1_8;
}

// ================= window JNI =================

JNIEXPORT jlong JNICALL Java_demo_FenShim_fenOpen
  (JNIEnv* env, jclass cls, jint w, jint h, jstring jtitle, jobject pixBuf)
{
  (void)cls;
  void* pixels = (*env)->GetDirectBufferAddress(env, pixBuf);
  if (!pixels) return 0;

  const char* title = (*env)->GetStringUTFChars(env, jtitle, 0);
  if (!title) return 0;

  struct fen_handle* hnd = (struct fen_handle*)calloc(1, sizeof *hnd);
  if (!hnd) { (*env)->ReleaseStringUTFChars(env, jtitle, title); return 0; }

  // Copy title to persist beyond this call
  hnd->title_copy = strdup(title);
  (*env)->ReleaseStringUTFChars(env, jtitle, title);

  // Build a temporary struct with const members set via initializer
  struct fenster tmp = {
    .title  = hnd->title_copy,
    .width  = (int)w,
    .height = (int)h,
    .buf    = (uint32_t*)pixels
  };

  // Assign via memcpy to satisfy const members (avoid field assigns)
  memcpy(&hnd->f, &tmp, sizeof tmp);

  if (fenster_open(&hnd->f) != 0) {
    free(hnd->title_copy);
    free(hnd);
    return 0;
  }
  return (jlong)(intptr_t)hnd;
}

JNIEXPORT jint JNICALL Java_demo_FenShim_fenLoop
  (JNIEnv* env, jclass cls, jlong p)
{
  (void)env; (void)cls;
  struct fen_handle* h = fen_from(p);
  if (!h) return -1;
  return fenster_loop(&h->f);
}

JNIEXPORT void JNICALL Java_demo_FenShim_fenClose
  (JNIEnv* env, jclass cls, jlong p)
{
  (void)env; (void)cls;
  struct fen_handle* h = fen_from(p);
  if (!h) return;
  fenster_close(&h->f);
  free(h->title_copy);
  free(h);
}

JNIEXPORT jint JNICALL Java_demo_FenShim_fenKey
  (JNIEnv* env, jclass cls, jlong p, jint code)
{
  (void)env; (void)cls;
  struct fen_handle* h = fen_from(p);
  if (!h) return 0;
  int k = (int)code;
  if (k < 0 || k >= 256) return 0;
  return h->f.keys[k];
}

JNIEXPORT void JNICALL Java_demo_FenShim_fenSleep
  (JNIEnv* env, jclass cls, jint ms)  // <-- CHANGED to jint
{
  (void)env; (void)cls;
  fenster_sleep((int)ms);
}

JNIEXPORT jlong JNICALL Java_demo_FenShim_fenTime
  (JNIEnv* env, jclass cls)
{
  (void)env; (void)cls;
  return (jlong)fenster_time();
}

// ================= audio JNI =================

JNIEXPORT jlong JNICALL Java_demo_FenShim_fenAudioOpen
  (JNIEnv* env, jclass cls)
{
  (void)env; (void)cls;
  struct aud_handle* a = (struct aud_handle*)calloc(1, sizeof *a);
  if (!a) return 0;
  if (fenster_audio_open(&a->fa) != 0) {
    free(a);
    return 0;
  }
  return (jlong)(intptr_t)a;
}

JNIEXPORT jint JNICALL Java_demo_FenShim_fenAudioAvail
  (JNIEnv* env, jclass cls, jlong p)
{
  (void)env; (void)cls;
  struct aud_handle* a = aud_from(p);
  if (!a) return 0;
  return (jint)fenster_audio_available(&a->fa);
}

JNIEXPORT void JNICALL Java_demo_FenShim_fenAudioWrite
  (JNIEnv* env, jclass cls, jlong p, jobject fbuf, jint n)
{
  (void)cls;
  struct aud_handle* a = aud_from(p);
  if (!a) return;
  void* addr = (*env)->GetDirectBufferAddress(env, fbuf);
  if (!addr) return;
  fenster_audio_write(&a->fa, (float*)addr, (size_t)n);
}

JNIEXPORT void JNICALL Java_demo_FenShim_fenAudioClose
  (JNIEnv* env, jclass cls, jlong p)
{
  (void)env; (void)cls;
  struct aud_handle* a = aud_from(p);
  if (!a) return;
  fenster_audio_close(&a->fa);
  free(a);
}

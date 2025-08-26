#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <jni.h>

#define FENSTER_IMPLEMENTATION
#include "fenster.h"
#include "demo_FenShim.h"

struct fen_handle {
  struct fenster f;
  char* title_copy;
}; // <= semicolon

// --- add this: lets the VM know the lib is JNI-ready
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
  (void)vm; (void)reserved;
  return JNI_VERSION_1_8;
}

static void* must_get_direct_buf_addr(JNIEnv* env, jobject buf) {
  void* addr = (*env)->GetDirectBufferAddress(env, buf);
  if (!addr) {
    jclass exc = (*env)->FindClass(env, "java/lang/IllegalArgumentException");
    (*env)->ThrowNew(env, exc, "Pixel buffer must be a direct ByteBuffer");
  }
  return addr;
}

JNIEXPORT jlong JNICALL Java_demo_FenShim_fenOpen
  (JNIEnv* env, jclass cls, jint width, jint height, jstring jtitle, jobject jbuf) {
  (void)cls;
  const char* title_utf = jtitle ? (*env)->GetStringUTFChars(env, jtitle, NULL) : "";
  char* title_dup = strdup(title_utf ? title_utf : "");
  if (jtitle) (*env)->ReleaseStringUTFChars(env, jtitle, title_utf);

  void* addr = must_get_direct_buf_addr(env, jbuf);
  if ((*env)->ExceptionCheck(env)) return 0;

  const struct fen_handle init = {
    .f = { .title = title_dup, .width = width, .height = height, .buf = (uint32_t*)addr },
    .title_copy = title_dup
  };

  struct fen_handle* h = (struct fen_handle*)malloc(sizeof *h);
  if (!h) { free(title_dup); return 0; }
  memcpy(h, &init, sizeof init);

  if (fenster_open(&h->f) < 0) { free(h->title_copy); free(h); return 0; }
  return (jlong)(uintptr_t)h;
}

JNIEXPORT jint JNICALL Java_demo_FenShim_fenLoop
  (JNIEnv* env, jclass cls, jlong handle) {
  (void)env; (void)cls;
  struct fen_handle* h = (struct fen_handle*)(uintptr_t)handle;
  return fenster_loop(&h->f);
}

JNIEXPORT void JNICALL Java_demo_FenShim_fenClose
  (JNIEnv* env, jclass cls, jlong handle) {
  (void)env; (void)cls;
  struct fen_handle* h = (struct fen_handle*)(uintptr_t)handle;
  if (!h) return;
  fenster_close(&h->f);
  free(h->title_copy);
  free(h);
}

JNIEXPORT jint JNICALL Java_demo_FenShim_fenKey
  (JNIEnv* env, jclass cls, jlong handle, jint code) {
  (void)env; (void)cls;
  struct fen_handle* h = (struct fen_handle*)(uintptr_t)handle;
  if (code < 0 || code > 255) return 0;
  return h->f.keys[code];
}

JNIEXPORT void JNICALL Java_demo_FenShim_fenSleep
  (JNIEnv* env, jclass cls, jint ms) {
  (void)env; (void)cls;
  fenster_sleep(ms);
}

JNIEXPORT jlong JNICALL Java_demo_FenShim_fenTime
  (JNIEnv* env, jclass cls) {
  (void)env; (void)cls;
  return (jlong)fenster_time();
}

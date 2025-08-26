# Clojure + Fenster (JNI) + GraalVM

Why JNI (not Panama/FFM)? On Apple Silicon, the GraalVM Native Image toolchain you’re likely using does not support the Foreign Function & Memory (FFM) API in native images for arm64 in a way that works here. JNI is stable on arm64 and works today.

---

## Requirements

- macOS 12+ on Apple Silicon (arm64)
- Xcode Command Line Tools: `cc`, `sips`, `iconutil`, `zip`
- GraalVM JDK 24 with `native-image` installed
- Clojure CLI (`clj` / `clojure`)
- `curl`

---

## Tools & dependencies

Languages / SDKs
- Clojure 1.12.2
- GraalVM 24
- Clang/LLVM (via Xcode tools)

Build tooling
- `clojure.tools.build` 0.10.5
- GraalVM native-image
- `make`

Runtime glue
- JNI (`JNI_OnLoad`, exported `Java_…` symbols)
- macOS frameworks: Cocoa, AudioToolbox

Third-party
- Fenster by @zserge — single-header windowing lib (`fenster.h`)
  https://github.com/zserge/fenster
- clj-easy/graal-build-time 1.0.5 — keeps essential Clojure namespaces initialized/retained inside native images
  https://github.com/clj-easy/graal-build-time

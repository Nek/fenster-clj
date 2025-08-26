#!/usr/bin/env bash
set -euo pipefail

# --- JDK/GraalVM ---
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 25)}"
export PATH="$JAVA_HOME/bin:$PATH"

# --- Layout ---
mkdir -p native resources/native target/classes

# --- Get Fenster header (always refresh; comment -o to skip overwriting) ---
curl -fsSL -o native/fenster.h https://raw.githubusercontent.com/zserge/fenster/main/fenster.h

# --- Compile Java JNI bridge + generate canonical JNI header ---
javac -h native -d target/classes src/demo/FenShim.java

# --- Build JNI dylib (arm64 macOS) with explicit symbol exports ---
cc -x c -arch arm64 -fPIC -dynamiclib native/fen_shim_jni.c -o native/libfen_shim_jni.dylib \
   -Inative -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" \
   -fvisibility=default \
   -Wl,-exported_symbol,_JNI_OnLoad \
   -Wl,-exported_symbol,_Java_demo_FenShim_fenOpen \
   -Wl,-exported_symbol,_Java_demo_FenShim_fenLoop \
   -Wl,-exported_symbol,_Java_demo_FenShim_fenClose \
   -Wl,-exported_symbol,_Java_demo_FenShim_fenKey \
   -Wl,-exported_symbol,_Java_demo_FenShim_fenSleep \
   -Wl,-exported_symbol,_Java_demo_FenShim_fenTime \
   -framework Cocoa -framework AudioToolbox

# Verify symbols (optional)
nm -gU native/libfen_shim_jni.dylib | grep -E 'JNI_OnLoad|Java_demo_FenShim_' || true

# --- Bundle dylib as classpath resource (so it’s inside the native image) ---
cp native/libfen_shim_jni.dylib resources/native/

# --- Compile Clojure/Java to classes (uses your build.clj) ---
clj -T:build clean
clj -T:build compile-all

# --- Build native image (include the dylib resource; init FenShim at runtime) ---
CP="$(clojure -Spath):resources:target/classes"

native-image -cp "$CP" \
  -H:Class=demo.fenhouse \
  --features=clj_easy.graal_build_time.InitClojureClasses \
  --initialize-at-run-time=demo.FenShim \
  -H:IncludeResources='^native/libfen_shim_jni\.dylib$' \
  --no-fallback \
  --enable-native-access=ALL-UNNAMED \
  -H:+ReportExceptionStackTraces \
  -O2 \
  -o fenhouse

echo "Built ./fenhouse"
echo "Running…"
./fenhouse

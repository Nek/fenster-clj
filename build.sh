#!/bin/bash

# Use GraalVM (with native-image installed)
export JAVA_HOME=$(/usr/libexec/java_home -v 25)
export PATH="$JAVA_HOME/bin:$PATH"

# Build JNI header + class (keeps symbols canonical)
mkdir -p target/classes native
javac -h native -d target/classes src/demo/FenShim.java

# Rebuild the JNI dylib (symbols explicitly exported)
cc -x c -arch arm64 -fPIC -dynamiclib native/fen_shim_jni.c -o native/libfen_shim_jni.dylib \
  -I"$JAVA_HOME/include" -I"$JAVA_HOME/include/darwin" \
  -fvisibility=default \
  -Wl,-exported_symbol,_JNI_OnLoad \
  -Wl,-exported_symbol,_Java_demo_FenShim_fenOpen \
  -Wl,-exported_symbol,_Java_demo_FenShim_fenLoop \
  -Wl,-exported_symbol,_Java_demo_FenShim_fenClose \
  -Wl,-exported_symbol,_Java_demo_FenShim_fenKey \
  -Wl,-exported_symbol,_Java_demo_FenShim_fenSleep \
  -Wl,-exported_symbol,_Java_demo_FenShim_fenTime \
  -framework Cocoa -framework AudioToolbox

# BUNDLE the dylib into the image as a classpath resource
mkdir -p resources/native
cp native/libfen_shim_jni.dylib resources/native/

# Compile everything (Java already compiled; AOT Clojure)
clj -T:build clean
clj -T:build compile-all

# Build native image:
#  - include the resource (regex) so it’s inside the binary
#  - init FenShim at run time (so static loader runs at startup)
CP="$(clojure -Spath):target/classes"
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

# Run it (no working-directory assumptions now)
./fenhouse

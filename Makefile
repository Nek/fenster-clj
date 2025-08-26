# ----- config --------------------------------------------------------------

SHELL := /bin/bash

JAVA_HOME ?= $(shell /usr/libexec/java_home -v 25)
PATH := $(JAVA_HOME)/bin:$(PATH)

CLJ      := clj
BIN      := fenhouse

HEADER        := native/fenster.h
JNI_HEADER    := native/demo_FenShim.h
JAVA_SRC      := src/demo/FenShim.java
JAVA_CLASS    := target/classes/demo/FenShim.class
NATIVE_SRC    := native/fen_shim_jni.c
NATIVE_DYLIB  := native/libfen_shim_jni.dylib
RES_DYLIB     := resources/native/libfen_shim_jni.dylib

CLJ_SOURCES   := $(shell find src -name '*.clj')
STAMP         := target/classes/.clj-compiled

# macOS arm64, Cocoa
CFLAGS   := -x c -arch arm64 -fPIC
LDFLAGS  := -dynamiclib -fvisibility=default \
            -Wl,-exported_symbol,_JNI_OnLoad \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenOpen \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenLoop \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenClose \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenKey \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenSleep \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenTime \
            -framework Cocoa -framework AudioToolbox

CP := $(shell clojure -Spath):resources:target/classes

# ----- top-level targets ---------------------------------------------------

.PHONY: all run run-jvm image classes clean distclean help
all: $(BIN)

help:
	@echo "make              # build native binary ($(BIN))"
	@echo "make run          # run native binary"
	@echo "make run-jvm      # run on JVM with :run alias"
	@echo "make classes      # build Java + AOT Clojure (incremental)"
	@echo "make clean        # remove target/ and binary"
	@echo "make distclean    # clean + remove headers/dylibs/resources"

run: $(BIN)
	./$(BIN)

run-jvm: $(RES_DYLIB) $(STAMP)
	$(CLJ) -M:run

image: $(BIN)

classes: $(STAMP)

clean:
	rm -rf target $(BIN)

distclean: clean
	rm -rf resources/native $(HEADER) $(JNI_HEADER) $(NATIVE_DYLIB)

# ----- build graph ---------------------------------------------------------

# 0) fetch fenster.h once (refreshed if deleted)
$(HEADER):
	mkdir -p native
	curl -fsSL -o $@ https://raw.githubusercontent.com/zserge/fenster/main/fenster.h

# 1) compile Java + generate canonical JNI header
$(JAVA_CLASS) $(JNI_HEADER): $(JAVA_SRC)
	mkdir -p target/classes native
	javac -h native -d target/classes $<

# 2) build JNI dylib with explicit exported symbols
$(NATIVE_DYLIB): $(NATIVE_SRC) $(HEADER) $(JNI_HEADER)
	cc $(CFLAGS) $(NATIVE_SRC) -o $@ \
	   -Inative -I"$(JAVA_HOME)/include" -I"$(JAVA_HOME)/include/darwin" \
	   $(LDFLAGS)

# 3) bundle dylib into resources (only copies when changed)
$(RES_DYLIB): $(NATIVE_DYLIB)
	mkdir -p resources/native
	cp -p $< $@

# 4) compile Clojure (AOT entrypoint) after Java is present
$(STAMP): $(CLJ_SOURCES) $(JAVA_CLASS)
	$(CLJ) -T:build compile-all
	@touch $@

# 5) build the native image (includes bundled dylib as resource)
$(BIN): $(RES_DYLIB) $(STAMP)
	native-image -cp "$(CP)" \
	  -H:Class=demo.fenhouse \
	  --features=clj_easy.graal_build_time.InitClojureClasses \
	  --initialize-at-run-time=demo.FenShim \
	  -H:IncludeResources='^native/libfen_shim_jni\.dylib$$' \
	  --no-fallback \
	  --enable-native-access=ALL-UNNAMED \
	  -H:+ReportExceptionStackTraces \
	  -O2 \
	  -o $(BIN)

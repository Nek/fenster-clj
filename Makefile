# ----- config --------------------------------------------------------------

SHELL := /bin/bash

JAVA_HOME ?= $(shell /usr/libexec/java_home -v 25)
PATH := $(JAVA_HOME)/bin:$(PATH)

CLJ      := clj
BIN      := fenhouse

# App bundle config
APP_NAME := FenHouse
APP      := $(APP_NAME).app
CONTENTS := $(APP)/Contents
MACOS    := $(CONTENTS)/MacOS
RES      := $(CONTENTS)/Resources
PLIST    := $(CONTENTS)/Info.plist
APP_ICON := resources/AppIcon.icns  # optional (see icon rule below)

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

.PHONY: all run run-jvm image classes app open-app clean distclean help
all: $(BIN)

help:
	@echo "make               # build native binary ($(BIN))"
	@echo "make run           # run native binary"
	@echo "make run-jvm       # run on JVM with :run alias"
	@echo "make app           # build macOS .app bundle ($(APP))"
	@echo "make open-app      # open the .app in Finder"
	@echo "make classes       # build Java + AOT Clojure (incremental)"
	@echo "make clean         # remove target/ and binary"
	@echo "make distclean     # clean + remove headers/dylibs/resources"

run: $(BIN)
	./$(BIN)

run-jvm: $(RES_DYLIB) $(STAMP)
	$(CLJ) -M:run

image: $(BIN)

app: $(APP)

open-app: $(APP)
	open "$(APP)"

classes: $(STAMP)

clean:
	rm -rf target $(BIN)

distclean: clean
	rm -rf resources/native $(HEADER) $(JNI_HEADER) $(NATIVE_DYLIB) $(APP)

# ----- build graph ---------------------------------------------------------

# 0) fetch fenster.h (refreshed if deleted)
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

# 3) bundle dylib into classpath resources (only copies when changed)
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

# ----- macOS .app bundling -------------------------------------------------

# optional icon pipeline: provide resources/icon.png to generate .icns
# (skip if you already have resources/AppIcon.icns)
resources/AppIcon.icns: resources/icon.png
	@echo "Generating AppIcon.icns from resources/icon.png"
	mkdir -p resources/AppIcon.iconset
	sips -z 16 16     $< --out resources/AppIcon.iconset/icon_16x16.png
	sips -z 32 32     $< --out resources/AppIcon.iconset/icon_16x16@2x.png
	sips -z 32 32     $< --out resources/AppIcon.iconset/icon_32x32.png
	sips -z 64 64     $< --out resources/AppIcon.iconset/icon_32x32@2x.png
	sips -z 128 128   $< --out resources/AppIcon.iconset/icon_128x128.png
	sips -z 256 256   $< --out resources/AppIcon.iconset/icon_128x128@2x.png
	sips -z 256 256   $< --out resources/AppIcon.iconset/icon_256x256.png
	sips -z 512 512   $< --out resources/AppIcon.iconset/icon_256x256@2x.png
	sips -z 512 512   $< --out resources/AppIcon.iconset/icon_512x512.png
	cp $< resources/AppIcon.iconset/icon_512x512@2x.png
	iconutil -c icns resources/AppIcon.iconset -o $@
	rm -rf resources/AppIcon.iconset

# Info.plist (generated)
$(PLIST):
	mkdir -p "$(RES)"
	@{ \
	  echo '<?xml version="1.0" encoding="UTF-8"?>'; \
	  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'; \
	  echo '<plist version="1.0"><dict>'; \
	  echo '  <key>CFBundleName</key><string>$(APP_NAME)</string>'; \
	  echo '  <key>CFBundleIdentifier</key><string>com.example.$(BIN)</string>'; \
	  echo '  <key>CFBundleExecutable</key><string>$(BIN)</string>'; \
	  echo '  <key>CFBundlePackageType</key><string>APPL</string>'; \
	  echo '  <key>LSMinimumSystemVersion</key><string>12.0</string>'; \
	  echo '  <key>NSHighResolutionCapable</key><true/>'; \
	  if [ -f "$(APP_ICON)" ]; then \
	    echo '  <key>CFBundleIconFile</key><string>AppIcon</string>'; \
	  fi; \
	  echo '</dict></plist>'; \
	} > "$(PLIST)"

# build the .app bundle
$(APP): $(BIN) $(PLIST) $(APP_ICON)
	mkdir -p "$(MACOS)" "$(RES)"
	cp -p "$(BIN)" "$(MACOS)/$(BIN)"
	# Optional: place the dylib alongside the binary (not required; image embeds it)
	@if [ -f "$(RES_DYLIB)" ]; then cp -p "$(RES_DYLIB)" "$(MACOS)/"; fi
	# Optional icon
	@if [ -f "$(APP_ICON)" ]; then cp -p "$(APP_ICON)" "$(RES)/"; fi
	@echo "App bundle created: $(APP)"

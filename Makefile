# ========================== config ==========================
SHELL := /bin/bash

# Try JDK 25 first, then 24. Override with:  JAVA_HOME=/path/to/graal make
JAVA_HOME ?= $(shell /usr/libexec/java_home -v 25 2>/dev/null || /usr/libexec/java_home -v 24)
PATH := $(JAVA_HOME)/bin:$(PATH)

CLJ  := clj

# main binaries
BIN_UI     := fenhouse
BIN_SOUND  := fensound

# macOS .app bundle names
APP_NAME_UI    := FenHouse
APP_NAME_SOUND := FenSound

APP_UI    := $(APP_NAME_UI).app
APP_SOUND := $(APP_NAME_SOUND).app

CONTENTS := Contents
MACOS    := $(CONTENTS)/MacOS
RES      := $(CONTENTS)/Resources

# optional icon (generated from resources/icon.png if present)
APP_ICON := resources/AppIcon.icns

# sources / outputs
HEADER        := native/fenster.h
AUDIO_HEADER  := native/fenster_audio.h
JNI_HEADER    := native/demo_FenShim.h
JAVA_SRC      := src/demo/FenShim.java
JAVA_CLASS    := target/classes/demo/FenShim.class
NATIVE_SRC    := native/fen_shim_jni.c
NATIVE_DYLIB  := native/libfen_shim_jni.dylib
RES_DYLIB     := resources/native/libfen_shim_jni.dylib

# stamps (separate so UI build doesn’t touch sound, and vice versa)
STAMP_UI      := target/classes/.fenhouse-compiled
STAMP_SOUND   := target/classes/.sound-compiled

# collect clj sources
CLJ_SOURCES   := $(shell find src -name '*.clj')

# toolchain (arm64 macOS)
CFLAGS   := -x c -arch arm64 -fPIC
LDFLAGS  := -dynamiclib -fvisibility=default \
            -Wl,-exported_symbol,_JNI_OnLoad \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenOpen \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenLoop \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenClose \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenKey \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenSleep \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenTime \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenAudioOpen \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenAudioAvail \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenAudioWrite \
            -Wl,-exported_symbol,_Java_demo_FenShim_fenAudioClose \
            -framework Cocoa -framework AudioToolbox

# full classpath for native-image
CP := $(shell clojure -Spath):resources:target/classes

# ======================= top-level ==========================
.PHONY: all ui sound app app-sound run run-jvm run-sound run-sound-jvm \
        image image-sound open-app open-app-sound clean distclean \
        classes headers zip zip-sound codesign codesign-sound help

all: app app-sound

headers: $(HEADER) $(AUDIO_HEADER)

# ---------- convenience ----------
ui: image
sound: image-sound

run: $(BIN_UI)
	./$(BIN_UI)

run-sound: $(BIN_SOUND)
	./$(BIN_SOUND)

# ensure classes exist and on classpath for JVM run
run-jvm: $(RES_DYLIB) $(JAVA_CLASS) $(STAMP_UI)
	$(CLJ) -M:run

run-sound-jvm: $(RES_DYLIB) $(JAVA_CLASS) $(STAMP_SOUND)
	$(CLJ) -M:run-sound

open-app: $(APP_UI)
	open "$(APP_UI)"

open-app-sound: $(APP_SOUND)
	open "$(APP_SOUND)"

zip: $(APP_UI)
	@rm -f $(APP_NAME_UI)-macOS-arm64.zip
	@/usr/bin/zip -r $(APP_NAME_UI)-macOS-arm64.zip "$(APP_UI)"

zip-sound: $(APP_SOUND)
	@rm -f $(APP_NAME_SOUND)-macOS-arm64.zip
	@/usr/bin/zip -r $(APP_NAME_SOUND)-macOS-arm64.zip "$(APP_SOUND)"

codesign: $(APP_UI)
	@codesign --force --deep --sign - "$(APP_UI)" && echo "codesigned (ad-hoc)"

codesign-sound: $(APP_SOUND)
	@codesign --force --deep --sign - "$(APP_SOUND)" && echo "codesigned (ad-hoc)"

clean:
	rm -rf target $(BIN_UI) $(BIN_SOUND)

distclean: clean
	rm -rf resources/native $(HEADER) $(AUDIO_HEADER) $(JNI_HEADER) $(NATIVE_DYLIB) \
	       $(APP_UI) $(APP_SOUND) \
	       resources/AppIcon.icns resources/AppIcon.iconset

# ===================== build graph ==========================

# 0) fetch headers (only if missing)
$(HEADER):
	mkdir -p native
	curl -fsSL -o $@ https://raw.githubusercontent.com/zserge/fenster/main/fenster.h

$(AUDIO_HEADER):
	mkdir -p native
	curl -fsSL -o $@ https://raw.githubusercontent.com/zserge/fenster/main/fenster_audio.h

# 1) compile Java + generate canonical JNI header
$(JAVA_CLASS) $(JNI_HEADER): $(JAVA_SRC)
	mkdir -p target/classes native
	javac -h native -d target/classes $<

# 2) build JNI dylib (with explicit exported symbols)
$(NATIVE_DYLIB): $(NATIVE_SRC) $(HEADER) $(AUDIO_HEADER) $(JNI_HEADER)
	cc $(CFLAGS) $(NATIVE_SRC) -o $@ \
	   -Inative -I"$(JAVA_HOME)/include" -I"$(JAVA_HOME)/include/darwin" \
	   $(LDFLAGS)

# 3) bundle dylib into classpath resources (for embedding)
$(RES_DYLIB): $(NATIVE_DYLIB)
	mkdir -p resources/native
	cp -p $< $@

# 4) compile Clojure (AOT entrypoints) after Java is present
$(STAMP_UI): $(JAVA_CLASS) $(filter %fenhouse.clj,$(CLJ_SOURCES))
	$(CLJ) -T:build compile-ui
	@touch $@

$(STAMP_SOUND): $(JAVA_CLASS) $(filter %sound.clj,$(CLJ_SOURCES))
	$(CLJ) -T:build compile-sound
	@touch $@

# 5a) build native image (UI)
$(BIN_UI): $(RES_DYLIB) $(STAMP_UI)
	native-image -cp "$(CP)" \
	  -H:Class=demo.fenhouse \
	  --features=clj_easy.graal_build_time.InitClojureClasses \
	  --initialize-at-run-time=demo.FenShim \
	  -H:IncludeResources='^native/libfen_shim_jni\.dylib$$' \
	  --no-fallback \
	  --enable-native-access=ALL-UNNAMED \
	  -H:+ReportExceptionStackTraces \
	  -O2 \
	  -o $(BIN_UI)

# 5b) build native image (SOUND)
$(BIN_SOUND): $(RES_DYLIB) $(STAMP_SOUND)
	native-image -cp "$(CP)" \
	  -H:Class=demo.sound \
	  --features=clj_easy.graal_build_time.InitClojureClasses \
	  --initialize-at-run-time=demo.FenShim \
	  -H:IncludeResources='^native/libfen_shim_jni\.dylib$$' \
	  --no-fallback \
	  --enable-native-access=ALL-UNNAMED \
	  -H:+ReportExceptionStackTraces \
	  -O2 \
	  -o $(BIN_SOUND)

# -------- macOS .app bundling --------

# optional icon pipeline: resources/icon.png -> AppIcon.icns
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

define WRITE_PLIST
mkdir -p "$(@)/$(RES)"
{ \
  echo '<?xml version="1.0" encoding="UTF-8"?>'; \
  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'; \
  echo '<plist version="1.0"><dict>'; \
  echo '  <key>CFBundleName</key><string>$(1)</string>'; \
  echo '  <key>CFBundleIdentifier</key><string>com.example.$(2)</string>'; \
  echo '  <key>CFBundleExecutable</key><string>$(2)</string>'; \
  echo '  <key>CFBundlePackageType</key><string>APPL</string>'; \
  echo '  <key>LSMinimumSystemVersion</key><string>12.0</string>'; \
  echo '  <key>NSHighResolutionCapable</key><true/>'; \
  if [ -f "$(APP_ICON)" ]; then \
    echo '  <key>CFBundleIconFile</key><string>AppIcon</string>'; \
  fi; \
  echo '</dict></plist>'; \
} > "$(@)/Contents/Info.plist"
endef

$(APP_UI): $(BIN_UI) resources/AppIcon.icns | $(RES_DYLIB)
	mkdir -p "$(@)/$(MACOS)" "$(@)/$(RES)"
	cp -p "$(BIN_UI)" "$(@)/$(MACOS)/$(BIN_UI)"
	cp -p "$(RES_DYLIB)" "$(@)/$(MACOS)/" || true
	@if [ -f "$(APP_ICON)" ]; then cp -p "$(APP_ICON)" "$(@)/$(RES)/"; fi
	$(call WRITE_PLIST,$(APP_NAME_UI),$(BIN_UI))
	@echo "App bundle created: $(APP_UI)"

$(APP_SOUND): $(BIN_SOUND) resources/AppIcon.icns | $(RES_DYLIB)
	mkdir -p "$(@)/$(MACOS)" "$(@)/$(RES)"
	cp -p "$(BIN_SOUND)" "$(@)/$(MACOS)/$(BIN_SOUND)"
	cp -p "$(RES_DYLIB)" "$(@)/$(MACOS)/" || true
	@if [ -f "$(APP_ICON)" ]; then cp -p "$(APP_ICON)" "$(@)/$(RES)/"; fi
	$(call WRITE_PLIST,$(APP_NAME_SOUND),$(BIN_SOUND))
	@echo "App bundle created: $(APP_SOUND)"

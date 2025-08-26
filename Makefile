JAVA_HOME := $(shell /usr/libexec/java_home -v 25)
PATH := $(JAVA_HOME)/bin:$(PATH)

CP := $(shell clojure -Spath):target/classes
NATIVE := native/libfen_shim_jni.dylib

all: run

$(NATIVE): native/fen_shim_jni.c native/fenster.h native/demo_FenShim.h
	cc -x c -arch arm64 -fPIC -dynamiclib $< -o $@ \
	   -I"$(JAVA_HOME)/include" -I"$(JAVA_HOME)/include/darwin" \
	   -fvisibility=default \
	   -Wl,-exported_symbol,_JNI_OnLoad \
	   -Wl,-exported_symbol,_Java_demo_FenShim_fenOpen \
	   -Wl,-exported_symbol,_Java_demo_FenShim_fenLoop \
	   -Wl,-exported_symbol,_Java_demo_FenShim_fenClose \
	   -Wl,-exported_symbol,_Java_demo_FenShim_fenKey \
	   -Wl,-exported_symbol,_Java_demo_FenShim_fenSleep \
	   -Wl,-exported_symbol,_Java_demo_FenShim_fenTime \
	   -framework Cocoa -framework AudioToolbox

native/demo_FenShim.h target/classes/demo/FenShim.class: src/demo/FenShim.java
	mkdir -p target/classes native
	javac -h native -d target/classes $<

classes: native/demo_FenShim.h
	clj -T:build compile-all

uber:
	clj -T:build uber

image: $(NATIVE) classes
	native-image -cp "$(CP)" -H:Class=demo.fenhouse \
	  --features=clj_easy.graal_build_time.InitClojureClasses \
	  --initialize-at-run-time=demo.FenShim \
	  --no-fallback --enable-native-access=ALL-UNNAMED \
	  -H:CLibraryPath=./native -H:+ReportExceptionStackTraces -O2 -o fenhouse

run-jvm: $(NATIVE) classes
	clj -M:run

run: image
	./fenhouse

clean:
	rm -rf target fenhouse

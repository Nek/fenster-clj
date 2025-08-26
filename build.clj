(ns build
  (:require [clojure.tools.build.api :as b]))

(def class-dir "target/classes")
(def basis     (b/create-basis {:project "deps.edn"}))
(def src-dirs  ["src"])

;; --- tasks -------------------------------------------------------------------

(defn clean [_]
  (b/delete {:path "target"})
  (println "cleaned target/"))

(defn javac [_]
  ;; Compile the Java JNI bridge first so Clojure can import demo.FenShim.
  (b/javac {:src-dirs  src-dirs
            :class-dir class-dir
            :basis     basis})
  (println "javac ->" class-dir))

(defn aot [_]
  ;; AOT-compile the Clojure entrypoint (requires (:gen-class :main true) in ns).
  (b/compile-clj {:basis      basis
                  :src-dirs   src-dirs
                  :class-dir  class-dir
                  :ns-compile ['demo.fenhouse]
                  :compile-opts {:direct-linking true}})
  (println "AOT Clojure ->" class-dir))

(defn compile-all [_]
  (clean nil)
  (javac nil)
  (aot nil)
  (println "classes ready in" class-dir))

;; OPTIONAL: build a runnable uberjar (not required for native-image)
(def uber-file "target/app.jar")

(defn uber [_]
  (compile-all nil)
  (b/uber {:class-dir class-dir
           :uber-file uber-file
           :basis     basis
           ;; set a Main-Class so `java -jar` runs your app directly
           :manifest {"Main-Class" "demo.fenhouse"
                      "Implementation-Title" "fenhouse"
                      "Implementation-Version" "0.1"}})
  (println "uberjar ->" uber-file))

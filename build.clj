(ns build
  (:require [clojure.tools.build.api :as b]))

(def class-dir "target/classes")
(def src-dirs  ["src"])
(def basis     (b/create-basis {:project "deps.edn"}))

(defn clean [_]
  (b/delete {:path "target"})
  (println "clean ok"))

(defn compile-ui [_]
  (b/compile-clj {:basis basis
                  :src-dirs src-dirs
                  :class-dir class-dir
                  :ns-compile ['demo.fenhouse]})
  (println "AOT: demo.fenhouse"))

(defn compile-sound [_]
  (b/compile-clj {:basis basis
                  :src-dirs src-dirs
                  :class-dir class-dir
                  :ns-compile ['demo.sound]})
  (println "AOT: demo.sound"))

(defn compile-all [_]
  (b/compile-clj {:basis basis
                  :src-dirs src-dirs
                  :class-dir class-dir
                  :ns-compile ['demo.fenhouse 'demo.sound]})
  (println "AOT: both"))

(ns build
  (:require [clojure.tools.build.api :as b]))

(def class-dir "target/classes")
(def basis     (b/create-basis {:project "deps.edn"}))
(def uber-file "target/app.jar")

(defn uber [_]
  (b/delete {:path "target"})
  (b/copy-dir {:src-dirs ["src"] :target-dir class-dir})
  (b/compile-clj {:basis basis :src-dirs ["src"] :class-dir class-dir})
  (b/uber {:class-dir class-dir
           :uber-file uber-file
           :basis basis
           :manifest {"Main-Class" "clojure.main"
                      "Implementation-Title" "fenhouse"
                      "Implementation-Version" "0.1"}}))   ;; has -main

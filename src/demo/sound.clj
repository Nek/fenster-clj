(ns demo.sound
  (:gen-class :main true)
  (:import [demo FenShim]
           [java.nio ByteBuffer IntBuffer FloatBuffer]))

(def ^:const W   320)
(def ^:const H   240)
(def ^:const FPS 60)
(def ^:const SR  48000.0)     ;; sample rate

(defn ^:private draw! [^IntBuffer ib t]
  (.clear ib)
  (let [n (* W H)]
    (loop [i 0]
      (when (< i n)
        (let [x   (unchecked-int (rem i W))
              y   (unchecked-int (quot i W))
              rgb (bit-and 0x00ffffff (bit-xor (bit-xor x y) (int t)))]
          (.put ib (int rgb))
          (recur (unchecked-inc i)))))))

(defn ^:private push-audio! [ah phase inc]
  (let [n (FenShim/fenAudioAvail ah)]
    (if (pos? n)
      (let [bb (ByteBuffer/allocateDirect (* 4 n))
            fb (.asFloatBuffer bb)
            ;; fill buffer with n sine samples, return new phase
            phase' (loop [i 0 ph (double phase)]
                     (if (< i n)
                       (do
                         (.put fb (float (Math/sin ph)))
                         (recur (unchecked-inc i) (+ ph inc)))
                       ph))]
        (.flip fb)
        (FenShim/fenAudioWrite ah fb n)
        (let [tau (* 2.0 Math/PI)]
          (if (> phase' tau) (rem phase' tau) phase')))
      phase)))

(defn -main [& _]
  ;; ensure JNI loader runs at runtime
  (Class/forName "demo.FenShim")

  (let [pix (ByteBuffer/allocateDirect (* W H 4))
        ib  (.asIntBuffer pix)
        wh  (FenShim/fenOpen W H "sound" pix)
        ah  (FenShim/fenAudioOpen)
        inc (/ (* 2.0 Math/PI 440.0) SR)]  ;; 440 Hz
    (try
      (loop [t 0, phase 0.0, now (FenShim/fenTime)]
        (when (zero? (FenShim/fenLoop wh))
          (draw! ib t)
          (let [phase (if (pos? ah) (push-audio! ah phase inc) phase)
                target (+ now (long (/ 1000 FPS)))
                remain (- target (FenShim/fenTime))]
            (when (pos? remain) (FenShim/fenSleep remain))
            (recur (unchecked-inc t) phase (FenShim/fenTime)))))
      (finally
        (when (pos? ah) (FenShim/fenAudioClose ah))
        (when (pos? wh) (FenShim/fenClose wh))))))

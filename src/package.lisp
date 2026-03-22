(defpackage #:net.lecigne.stumpwm.core
  (:use #:cl)
  (:export #:sanitize-string))

(defpackage #:net.lecigne.stumpwm.bluetooth
  (:use #:cl)
  (:export #:make-device
           #:toggle
           #:devices
           #:toggle-device))

(defpackage #:net.lecigne.stumpwm.sound
  (:use #:cl)
  (:export #:parse-volume-state))

(defpackage #:net.lecigne.stumpwm
  (:use #:cl #:stumpwm)
  (:local-nicknames (#:core #:net.lecigne.stumpwm.core)
                    (#:bluetooth #:net.lecigne.stumpwm.bluetooth)
                    (#:sound #:net.lecigne.stumpwm.sound)))

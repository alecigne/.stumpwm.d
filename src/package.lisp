(defpackage #:net.lecigne.stumpwm.core
  (:use #:cl)
  (:nicknames #:stumpwm-config-core)
  (:export #:sanitize-string))

(defpackage #:net.lecigne.stumpwm.bluetooth
  (:use #:cl)
  (:nicknames #:stumpwm-config-bluetooth)
  (:export #:toggle
           #:devices
           #:toggle-device))

(defpackage #:net.lecigne.stumpwm
  (:use #:cl #:stumpwm)
  (:local-nicknames (#:core #:net.lecigne.stumpwm.core)
                    (#:bluetooth #:net.lecigne.stumpwm.bluetooth)))

(defpackage #:net.lecigne.stumpwm.core
  (:use #:cl)
  (:export #:sanitize-string))

(defpackage #:net.lecigne.stumpwm.bluetooth
  (:use #:cl)
  (:export #:make-device
           #:toggle
           #:devices
           #:toggle-device))

(defpackage #:net.lecigne.stumpwm.display
  (:use #:cl)
  (:export #:brightness-current
           #:brightness-set
           #:brightness-shift
           #:brightness-reset
           #:color-temperature-current
           #:color-temperature-set
           #:color-temperature-shift
           #:color-temperature-reset
           #:night-mode-p
           #:night-mode-on
           #:night-mode-off
           #:night-mode))

(defpackage #:net.lecigne.stumpwm.sound
  (:use #:cl)
  (:export #:adjust-volume
           #:toggle-mute))

(defpackage #:net.lecigne.stumpwm
  (:use #:cl #:stumpwm)
  (:local-nicknames (#:core #:net.lecigne.stumpwm.core)
                    (#:bluetooth #:net.lecigne.stumpwm.bluetooth)
                    (#:display #:net.lecigne.stumpwm.display)
                    (#:sound #:net.lecigne.stumpwm.sound)))

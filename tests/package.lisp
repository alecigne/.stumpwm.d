(defpackage #:net.lecigne.stumpwm.tests
  (:use #:cl #:fiveam)
  (:export #:run-tests)
  (:local-nicknames (#:core #:net.lecigne.stumpwm.core)
                    (#:bluetooth #:net.lecigne.stumpwm.bluetooth)
                    (#:display #:net.lecigne.stumpwm.display)
                    (#:sound #:net.lecigne.stumpwm.sound)
                    (#:vpn #:net.lecigne.stumpwm.vpn)))

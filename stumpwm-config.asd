(asdf:defsystem "stumpwm-config"
  :description "alecigne's StumpWM configuration"
  :author "Anthony Le Cigne"
  :license "MIT"
  :depends-on (:alexandria
               :cl-ppcre
               :clx-truetype
               :local-time
               :slynk
               :stumpwm)
  :in-order-to ((test-op (test-op "stumpwm-config/tests")))
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "package")
                             (:file "core")
                             (:file "bluetooth")
                             (:file "config")))))

(asdf:defsystem "stumpwm-config/tests"
  :description "Tests for alecigne's StumpWM configuration"
  :author "Anthony Le Cigne"
  :license "MIT"
  :depends-on (:stumpwm
               :fiveam)
  :serial t
  :components (;; This avoid loading "config", as it needs a StumpWM session.
               (:module "src"
                :serial t
                :components ((:file "package")
                             (:file "core")))
               (:module "tests"
                :serial t
                :components ((:file "package")
                             (:file "config"))))
  :perform (test-op (o c)
             (uiop:symbol-call :stumpwm-config-tests :run-tests)))

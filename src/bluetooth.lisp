(defpackage #:net.lecigne.stumpwm.bluetooth
  (:use #:cl)
  (:export #:powered-p))

(in-package #:net.lecigne.stumpwm.bluetooth)

(defun powered-p ()
  (multiple-value-bind (out err code)
      (uiop:run-program '("bluetoothctl" "show")
                        :force-shell nil
                        :output :string
                        :error-output :string
                        :ignore-error-status t)
    (declare (ignore err))
    (and (zerop code)
         (not (null (search "Powered: yes" out :test #'char-equal))))))

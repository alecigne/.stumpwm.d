(in-package #:stumpwm-config-tests)

(def-suite stumpwm-config-suite
  :description "Tests for stumpwm-config core utilities.")

(in-suite stumpwm-config-suite)

(test sanitize-string
  (is (string= "hello"
               (stumpwm-config-core:sanitize-string
                (format nil "  hello~%"))))
  (is (string= "spaced middle"
               (stumpwm-config-core:sanitize-string
                (format nil "~C spaced middle ~C~C"
                        #\Tab #\Return #\Linefeed))))
  (is (string= ""
               (stumpwm-config-core:sanitize-string
                (format nil " ~C~C~C"
                        #\Newline #\Tab #\Return)))))

(defun run-tests ()
  (run! 'stumpwm-config-suite))

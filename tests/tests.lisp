(in-package #:net.lecigne.stumpwm.tests)

(def-suite stumpwm-config-suite
  :description "Tests for stumpwm-config utilities.")

(in-suite stumpwm-config-suite)

(test sanitize-string-trims-leading-and-trailing-whitespace
  "sanitize-string removes surrounding whitespace characters and preserves the middle."
  (is (string= "hello" (core:sanitize-string (format nil "  hello~%")))
      "leading spaces and trailing newlines should be trimmed")
  (is (string= "spaced middle"
               (core:sanitize-string
                (format nil "~C spaced middle ~C~C" #\Tab #\Return #\Linefeed)))
      "interior spaces should be preserved")
  (is (string= "" (core:sanitize-string
                   (format nil " ~C~C~C" #\Newline #\Tab #\Return)))
      "all-whitespace strings should become empty"))

(test bluetooth-make-device-parses-mac-and-name
  "make-device keeps the MAC and joins the remaining words into the device name."
  (let ((device (bluetooth:make-device "Device 11:22:33:44:55:66 WH-1000XM5")))
    (is (string= "11:22:33:44:55:66" (getf device :mac))
        "the MAC address should come from the second field")
    (is (string= "WH-1000XM5" (getf device :name))
        "a single-word device name should be preserved")))

(test bluetooth-make-device-parses-multi-word-names
  "make-device supports bluetoothctl output where the device name contains spaces."
  (let ((device (bluetooth:make-device
                 "Device AA:BB:CC:DD:EE:FF Quiet Comfort Ultra")))
    (is (string= "AA:BB:CC:DD:EE:FF" (getf device :mac))
        "the MAC address should still parse correctly")
    (is (string= "Quiet Comfort Ultra" (getf device :name))
        "all trailing words should be joined back into the device name")))

(test parse-volume-state-parses-unmuted-output
  "parse-volume-state returns a numeric volume and NIL for ordinary wpctl output."
      (multiple-value-bind (volume muted-p)
          (sound::parse-volume-state "Volume: 0.50")
    (is (= 0.5 volume)
        "the numeric volume should be parsed from the wpctl output")
    (is (null muted-p)
        "an unmuted line should return NIL for the muted flag")))

(test parse-volume-state-parses-muted-output
  "parse-volume-state detects the [MUTED] suffix and returns T for the muted flag."
  (multiple-value-bind (volume muted-p)
      (sound::parse-volume-state "Volume: 1.00 [MUTED]")
    (is (= 1.0 volume)
        "the numeric volume should still be parsed when muted")
    (is-true muted-p "the [MUTED] marker should set the muted flag to T")))

(test parse-volume-state-signals-on-invalid-output
  "parse-volume-state fails fast when wpctl output does not match the expected format."
  (signals error
    (sound::parse-volume-state "not a wpctl volume line")
    "unexpected wpctl output should signal an error"))

(defun run-tests ()
  (run! 'stumpwm-config-suite))

;; * Notes

;; TODO Avoid using internal symbols, don't test implementation. In this case it
;; was quite handy and easy, and well, this is just a StumpWM config after all
;; :)

;; * Emacs config

;;; Local Variables:
;;; eval: (display-fill-column-indicator-mode)
;;; End:

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

(test brightness-set-normalizes-and-caches-value
  "brightness-set clamps, rounds, and caches the value written to brightnessctl."
  (let ((written nil)
        (display::*brightness-current* nil))
    (let ((display::*brightness-writer*
            (lambda (value) (setf written value))))
      (is (= 100 (display:brightness-set 120)))
      (is (= 100 written))
      (is (= 0 (display:brightness-set -10)))
      (is (= 0 written))
      (is (= 43 (display:brightness-set 42.6)))
      (is (= 43 written))
      (is (= 43 (display:brightness-current))))))

(test brightness-shift-uses-cached-value
  "brightness-shift applies its delta to the cached brightness."
  (let ((written nil)
        (display::*brightness-current* 40))
    (let ((display::*brightness-writer*
            (lambda (value) (setf written value))))
      (is (= 35 (display:brightness-shift -5)))
      (is (= 35 written))
      (is (= 35 (display:brightness-current))))))

(test brightness-shift-defaults-to-full-brightness
  "brightness-shift uses 100 as its baseline when no value is cached."
  (let ((written nil)
        (display::*brightness-current* nil))
    (let ((display::*brightness-writer*
            (lambda (value) (setf written value))))
      (is (= 95 (display:brightness-shift -5)))
      (is (= 95 written))
      (is (= 95 (display:brightness-current))))))

(test brightness-set-preserves-cache-on-write-failure
  "brightness-set updates its cache only after the system write succeeds."
  (let ((display::*brightness-current* 40)
        (display::*brightness-writer*
          (lambda (value)
            (declare (ignore value))
            (error "Cannot set brightness"))))
    (signals error (display:brightness-set 80))
    (is (= 40 (display:brightness-current)))))

(test brightness-reset-sets-full-brightness
  "brightness-reset writes and caches full brightness."
  (let ((written nil)
        (display::*brightness-current* 40))
    (let ((display::*brightness-writer*
            (lambda (value) (setf written value))))
      (is (= 100 (display:brightness-reset)))
      (is (= 100 written))
      (is (= 100 (display:brightness-current))))))

(test color-temperature-defaults-to-maximum-temperature
  "The initial color temperature is the normal 6500K setting."
  (is (= 6500 (display:color-temperature-current))))

(test color-temperature-set-normalizes-and-caches-value
  "color-temperature-set clamps, rounds, and caches the written temperature."
  (let ((written nil)
        (display::*color-temperature-current* nil))
    (let ((display::*color-temperature-writer*
            (lambda (kelvin) (setf written kelvin))))
      (is (= 6500 (display:color-temperature-set 7000)))
      (is (= 6500 written))
      (is (= 4500 (display:color-temperature-set 4000)))
      (is (= 4500 written))
      (is (= 5201 (display:color-temperature-set 5200.6)))
      (is (= 5201 written))
      (is (= 5201 (display:color-temperature-current))))))

(test color-temperature-shift-uses-cached-value
  "color-temperature-shift applies its delta to the cached temperature."
  (let ((written nil)
        (display::*color-temperature-current* 5500))
    (let ((display::*color-temperature-writer*
            (lambda (kelvin) (setf written kelvin))))
      (is (= 5000 (display:color-temperature-shift -500)))
      (is (= 5000 written))
      (is (= 5000 (display:color-temperature-current))))))

(test color-temperature-shift-defaults-to-maximum-temperature
  "color-temperature-shift uses 6500K when no temperature is cached."
  (let ((written nil)
        (display::*color-temperature-current* nil))
    (let ((display::*color-temperature-writer*
            (lambda (kelvin) (setf written kelvin))))
      (is (= 6000 (display:color-temperature-shift -500)))
      (is (= 6000 written))
      (is (= 6000 (display:color-temperature-current))))))

(test color-temperature-set-preserves-cache-on-write-failure
  "color-temperature-set updates its cache only after the system write succeeds."
  (let ((display::*color-temperature-current* 5500)
        (display::*color-temperature-writer*
          (lambda (kelvin)
            (declare (ignore kelvin))
            (error "Cannot set color temperature"))))
    (signals error (display:color-temperature-set 5000))
    (is (= 5500 (display:color-temperature-current)))))

(test color-temperature-reset-sets-maximum-temperature
  "color-temperature-reset writes and caches 6500K."
  (let ((written nil)
        (display::*color-temperature-current* 5000))
    (let ((display::*color-temperature-writer*
            (lambda (kelvin) (setf written kelvin))))
      (is (= 6500 (display:color-temperature-reset)))
      (is (= 6500 written))
      (is (= 6500 (display:color-temperature-current))))))

(test night-mode-on-applies-night-profile
  "night-mode-on applies the night display profile and records its state."
  (let ((brightness-written nil)
        (temperature-written nil)
        (display::*brightness-current* nil)
        (display::*color-temperature-current* nil)
        (display::*night-mode-enabled-p* nil))
    (let ((display::*brightness-writer*
            (lambda (value) (setf brightness-written value)))
          (display::*color-temperature-writer*
            (lambda (kelvin) (setf temperature-written kelvin))))
      (is-true (display:night-mode-on))
      (is (= 90 brightness-written))
      (is (= 4500 temperature-written))
      (is (= 90 (display:brightness-current)))
      (is (= 4500 (display:color-temperature-current)))
      (is-true (display:night-mode-p)))))

(test night-mode-off-applies-default-profile
  "night-mode-off restores the default display profile and records its state."
  (let ((brightness-written nil)
        (temperature-written nil)
        (display::*brightness-current* 90)
        (display::*color-temperature-current* 4500)
        (display::*night-mode-enabled-p* t))
    (let ((display::*brightness-writer*
            (lambda (value) (setf brightness-written value)))
          (display::*color-temperature-writer*
            (lambda (kelvin) (setf temperature-written kelvin))))
      (is (null (display:night-mode-off)))
      (is (= 100 brightness-written))
      (is (= 6500 temperature-written))
      (is (= 100 (display:brightness-current)))
      (is (= 6500 (display:color-temperature-current)))
      (is (null (display:night-mode-p))))))

(test night-mode-switches-between-profiles
  "night-mode selects a profile from the cached night-mode state."
  (let ((display::*brightness-current* nil)
        (display::*color-temperature-current* nil)
        (display::*night-mode-enabled-p* nil)
        (display::*brightness-writer* (lambda (value) (declare (ignore value))))
        (display::*color-temperature-writer*
          (lambda (kelvin) (declare (ignore kelvin)))))
    (is-true (display:night-mode))
    (is-true (display:night-mode-p))
    (is (null (display:night-mode)))
    (is (null (display:night-mode-p)))))

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

(in-package #:net.lecigne.stumpwm.display)

;; * Brightness

(defvar *brightness-current* nil)

(defun brightness-current ()
  *brightness-current*)

(defun brightness-write (value)
  (uiop:run-program
   (list "brightnessctl" "set" (format nil "~D%" value))))

(defparameter *brightness-writer* #'brightness-write)

(defun brightness-set (value)
  (let ((value (alexandria:clamp (round value) 0 100)))
    (funcall *brightness-writer* value)
    (setf *brightness-current* value)
    value))

(defun brightness-shift (delta)
  (brightness-set (+ (or (brightness-current) 100) delta)))

(defun brightness-reset ()
  (brightness-set 100))

;; * Color temperature

(defparameter *color-temperature-min* 4500)
(defparameter *color-temperature-max* 6500)
(defvar *color-temperature-current* *color-temperature-max*)

(defun color-temperature-current ()
  *color-temperature-current*)

(defun color-temperature-write (kelvin)
  (uiop:run-program
   (list "redshift" "-PO" (format nil "~D" kelvin))))

(defparameter *color-temperature-writer* #'color-temperature-write)

(defun color-temperature-set (kelvin)
  (let ((kelvin (alexandria:clamp
                 (round kelvin)
                 *color-temperature-min*
                 *color-temperature-max*)))
    (funcall *color-temperature-writer* kelvin)
    (setf *color-temperature-current* kelvin)
    kelvin))

(defun color-temperature-shift (delta)
  (color-temperature-set
   (+ (or (color-temperature-current) *color-temperature-max*) delta)))

(defun color-temperature-reset ()
  (color-temperature-set *color-temperature-max*))

;; * Night mode

(defparameter *night-mode-brightness* 90)
(defvar *night-mode-enabled-p* nil)

(defun night-mode-p ()
  *night-mode-enabled-p*)

(defun night-mode-on ()
  (color-temperature-set *color-temperature-min*)
  (brightness-set *night-mode-brightness*)
  (setf *night-mode-enabled-p* t))

(defun night-mode-off ()
  (color-temperature-reset)
  (brightness-reset)
  (setf *night-mode-enabled-p* nil))

(defun night-mode ()
  (if (night-mode-p)
      (night-mode-off)
      (night-mode-on)))

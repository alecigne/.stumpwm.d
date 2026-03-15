(defpackage #:net.lecigne.stumpwm.bluetooth
  (:use #:cl)
  (:export #:toggle
           #:devices
           #:toggle-device))

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

(defun toggle ()
  (let ((new-state (if (powered-p) "off" "on")))
    (uiop:run-program
     (list "bluetoothctl" "power" new-state)
     :force-shell nil
     :ignore-error-status nil
     :output nil
     :error-output nil)))

(defun make-device (device-string)
  "Make a Bluetooth device from a DEVICE-STRING.
DEVICE-STRINGs look like this: Device 11:22:33:44:55:66 NAME.
A Bluetooth device is a plist: (:mac MAC :name NAME)."
  (let ((components (uiop:split-string device-string :separator '(#\Space))))
    (list :mac  (second components)
          :name (format nil "~{~A~^ ~}" (cddr components)))))

(defun devices ()
  "Return a list of Bluetooth devices."
  (let ((device-strings
          (uiop:run-program '("bluetoothctl" "devices") :output :lines)))
    (mapcar #'make-device device-strings)))

(defun device-connected-p (device)
  "Check if DEVICE is connected or not."
  (let ((info (uiop:run-program
               (list "bluetoothctl" "info" (getf device :mac))
               :output :string)))
    (not (null (search "Connected: yes" info)))))

(defun toggle-device (device)
  "Toggle connection of Bluetooth DEVICE."
  (let ((command (if (device-connected-p device)
                     "disconnect"
                     "connect")))
    (uiop:run-program (list "bluetoothctl" command (getf device :mac)))))

(in-package #:net.lecigne.stumpwm.sound)

(defparameter *volume-state-scanner*
  (cl-ppcre:create-scanner "^Volume:\\s+(\\S+)(?:\\s+(\\[MUTED\\]))?\\s*$"))

;; TODO Move more sound code here

(defun parse-real (s)
  (let ((*read-eval* nil))
    (read-from-string s)))

(defun parse-volume-state (s)
  (multiple-value-bind (match registers)
      (cl-ppcre:scan-to-strings *volume-state-scanner* s)
    (unless match (error "Cannot parse volume state: ~S" s))
    (values (parse-real (aref registers 0))
            (not (null (aref registers 1))))))

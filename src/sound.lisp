(in-package #:net.lecigne.stumpwm.sound)

;; Internal

(defparameter *volume-max* 1.0)

(defparameter *volume-state-scanner*
  (cl-ppcre:create-scanner "^Volume:\\s+(\\S+)(?:\\s+(\\[MUTED\\]))?\\s*$"))

(defun parse-real (s)
  (let ((*read-eval* nil))
    (read-from-string s)))

(defun parse-volume-state (s)
  (multiple-value-bind (match registers)
      (cl-ppcre:scan-to-strings *volume-state-scanner* s)
    (unless match (error "Cannot parse volume state: ~S" s))
    (values (parse-real (aref registers 0))
            (not (null (aref registers 1))))))

;; TODO Do better than calling sh.
(defun exec-wpctl-and-get-vol (cmd)
  (let* ((get-cmd "wpctl get-volume @DEFAULT_SINK@")
         (final-cmd (concatenate 'string cmd " && " get-cmd)))
    (parse-volume-state
     (uiop:run-program (list "sh" "-c" final-cmd) :output :string))))

;; API

(defun adjust-volume (delta)
  (exec-wpctl-and-get-vol
   (format nil
           "wpctl set-volume -l ~,2f @DEFAULT_SINK@ ~D~A"
           *volume-max* (abs delta) (if (minusp delta) "-" "+"))))

(defun toggle-mute ()
  (exec-wpctl-and-get-vol "wpctl set-mute @DEFAULT_SINK@ toggle"))

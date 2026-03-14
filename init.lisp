(in-package #:stumpwm)

;; * Meta
;; Lisp stuff that helps playing with StumpWM itself but doesn't change the
;; experience yet.

;; ** Dependencies

;; An ASDF system might be cool in the future, overkill for now.
(ql:quickload '(:alexandria
                :slynk
                :local-time
                :cl-ppcre)
              :silent t)

;; ** Helpers

(defun sanitize-string (string)
  (string-trim
   '(#\Space #\Newline #\Backspace #\Tab #\Linefeed #\Page #\Return #\Rubout)
   string))

(defun sh (control-str &rest args)
  "Run CONTROL-STR through FORMAT and execute it via StumpWM.
If the final arguments are :OUTPUT t, run synchronously and return sanitized
stdout; otherwise launch asynchronously."
  (let* ((output-arg-p (and (>= (length args) 2)
                            (eq (nth (- (length args) 2) args) :output)))
         (output-p (and output-arg-p (nth (- (length args) 1) args)))
         (fmt-args (if output-arg-p (butlast args 2) args))
         (cmd (apply #'format nil control-str fmt-args)))
    (if output-p
        (sanitize-string (run-shell-command cmd t))
        (run-shell-command cmd))))

(defmacro aif (test then &optional else)
  "Anaphoric if."
  `(let ((it ,test))
     (if it ,then ,else)))

(defmacro defkeys (map &body bindings)
  (alexandria:with-gensyms (m)
    `(let ((,m ,map))
       ,@(loop for (key command) in bindings
               collect `(define-key ,m (kbd ,key) ,command)))))

(defmacro defco (&rest args) `(defcommand ,@args))

(defun select-object-from-menu (screen prompt xs &key display-fn)
  "Display XS in a menu using DISPLAY-FN and return the selected object."
  (let* ((table (mapcar (lambda (x) (list (funcall display-fn x) x)) xs))
         (choice (select-from-menu screen table prompt)))
    (when choice (second choice))))

(defun colorize (style control &rest args)
  (format nil "^[~a~a^]" style (apply #'format nil control args)))

(defun color-up (control &rest args)
  (apply #'colorize "^2^B" control args))

(defun color-down (control &rest args)
  (apply #'colorize "^1^B" control args))

(defun color-warn (control &rest args)
  (apply #'colorize "^3^B" control args))

;; ** Slynk

(defvar *slynk-server* nil)

(defco slynk-start () ()
  (unless *slynk-server*
    (setf *slynk-server* (slynk:create-server :port 4006 :dont-close t)))
  (message "Slynk server ~A" (color-up "started")))

(defco slynk-stop () ()
  (when *slynk-server*
    (slynk:stop-server *slynk-server*)
    (setf *slynk-server* nil)
    (message "Slynk server ~A" (color-down "stopped"))))

(defun stop-slynk-on-exit () (ignore-errors (slynk-stop)))

(pushnew 'stop-slynk-on-exit *quit-hook*)
(pushnew 'stop-slynk-on-exit *restart-hook*)

;; ** Modules

;; TODO Do not hardcode this
(set-module-dir "~/src/stumpwm-contrib/")

;; * Basic customization

(setf *startup-message* "^5Lisp ^2^bsystem operational. Welcome!")
(setf *suppress-frame-indicator* t)
(setf *window-name-source* :class)
(setf *message-window-gravity* :bottom-right
      *message-window-margin* 18
      *message-window-y-margin* 12)
(setf *input-window-gravity* :bottom-right)
(setf *mode-line-position* :bottom)
(setf *grab-pointer-foreground* (xlib:make-color :red 1 :green 0 :blue 0))
(setf *grab-pointer-background* (lookup-color (current-screen) "DeepSkyBlue"))
(setf *grab-pointer-character* 24)
(setf *grab-pointer-character-mask* 24)

;; This solves white borders around Emacs. `frame-resize-pixelwise' can also be
;; set to T in Emacs to work well with this option.
(setf *ignore-wm-inc-hints* t)

(sh "xsetroot -cursor_name left_ptr")

;; ** Modeline

(load-module "battery-portable")

(defun modeline-time ()
  (let ((now (local-time:now)))
    (format nil "~a w~a d~d ~a"
            (local-time:format-timestring
             nil now
             :format '((:year 4) #\- (:month 2) #\- (:day 2)))
            (local-time:format-timestring
             nil now
             :format '((:iso-week-number 2)))
            (local-time:timestamp-day-of-week now)
            (local-time:format-timestring
             nil now
             :format '((:hour 2) #\: (:min 2))))))

(setf *mode-line-timeout* 60)

(setf *screen-mode-line-format*
      '("[^B%n^b] %W^> "
        " | "
        "bat: %B"
        " | "
        (:eval (modeline-time))))

(mode-line)

;; * Appearance

(load-module "ttf-fonts")
(xft:cache-fonts)
(set-font (make-instance 'xft:font
                         :family "JetBrains Mono"
                         :subfamily "Regular"
                         :size 12
                         :antialias t))

;; * Windows and groups

(defun move-window (delta)
  (let* ((win (current-window))
         (n (window-number win))
         (target (+ n delta)))
    (cond
      ((< target 0) nil)
      ((minusp delta) (renumber target) target)
      (t
       (let* ((windows (group-windows (current-group)))
              (max-n (reduce #'max windows :key #'window-number)))
         (when (<= target max-n)
           (renumber target)
           target))))))

(defco move-window-left () () (move-window -1))
(defco move-window-right () () (move-window 1))

;; * Applications

;; ** Usual suspects

(defco firefox () ()
  (run-or-raise "firefox-esr" '(:class "firefox-esr")))

(defco rofi () () (sh "rofi -show combi"))
(defco alacritty () () (sh "alacritty"))

;; ** xsecurelock

(defco lock-screen () ()
  (sh "XSECURELOCK_PASSWORD_PROMPT=asterisks xsecurelock"))

;; ** Redshift

(defparameter *redshift-min* 4500)
(defparameter *redshift-max* 6500)
(defparameter *redshift-step* 500)
(defvar *redshift-current* nil)

(defun redshift-message (kelvin)
  (message "Color temperature is now ~A" (color-up "~DK" kelvin)))

(defco redshift-set (kelvin) ((:number "Kelvin: "))
  (let ((k (alexandria:clamp (round kelvin) *redshift-min* *redshift-max*)))
    (setf *redshift-current* k)
    (sh "redshift -PO ~D" k)
    (redshift-message k)
    k))

(defun redshift-shift (delta)
  (redshift-set (+ (or *redshift-current* *redshift-max*) delta)))

(defco redshift-reset () ()
  (redshift-set *redshift-max*))

(defco redshift-warmer (&optional (step *redshift-step*)) ()
  (redshift-shift (- step)))

(defco redshift-cooler (&optional (step *redshift-step*)) ()
  (redshift-shift step))

;; ** brightnessctl

(defvar *brightness-current* nil)

(defco brightness-set (value) ((:number "Value: "))
  (let ((v (alexandria:clamp (round value) 0 100)))
    (setf *brightness-current* v)
    (sh "brightnessctl set ~D%" v)
    (message "Brightness is now ~A" (color-up "~D%" v))
    v))

(defun brightness-shift (delta)
  (brightness-set (+ (or *brightness-current* 100) delta)))

(defco brightness-reset () () (brightness-set 100))

(defco brightness-decrease (&optional (step 5)) ()
  (brightness-shift (- step)))

(defco brightness-increase (&optional (step 5)) ()
  (brightness-shift step))

(defkeys *top-map*
  ("XF86MonBrightnessDown" "brightness-decrease")
  ("XF86MonBrightnessUp"   "brightness-increase"))

(defvar *night-mode-p* nil)

(defun night-mode-disable ()
  (redshift-reset)
  (brightness-reset)
  (setf *night-mode-p* nil)
  (message "Night mode ~A" (color-down "disabled")))

(defun night-mode-enable ()
  (redshift-set *redshift-min*)
  (brightness-set 90)
  (setf *night-mode-p* t)
  (message "Night mode ~A" (color-up "enabled")))

(defco night-mode-toggle () ()
  (if *night-mode-p*
      (night-mode-disable)
      (night-mode-enable)))

;; ** NordVPN

(defun nord-status ()
  (sh "nordvpn status" :output t))

(defco nord-connect (&optional target) ((:string "Target: "))
  (sh "nordvpn connect ~A" (aif target it "france") :output t))

(defun nord-disconnect ()
  (sh "nordvpn disconnect" :output t))

;; ** screenshot

(defun do-screenshot (&optional area-p)
  (sh (if area-p
          "screenshot -s ~/tmp/screenshots/"
          "screenshot ~/tmp/screenshots/")))

(defco screenshot () ()
  (do-screenshot))

(defco screenshot-area () ()
  (do-screenshot t))

;; * Sound

(defparameter *volume-step* 0.05)
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

(defun exec-wpctl-and-get-vol (cmd)
  (let* ((get-cmd "wpctl get-volume @DEFAULT_SINK@")
         (final-cmd (concat cmd " && " get-cmd)))
    (parse-volume-state (sh final-cmd :output t))))

(defun audio-volume (delta)
  (exec-wpctl-and-get-vol
   (format nil
           "wpctl set-volume -l ~,2f @DEFAULT_SINK@ ~D~A"
           *volume-max* (abs delta) (if (minusp delta) "-" "+"))))

(defun audio-toggle-mute* ()
  (exec-wpctl-and-get-vol "wpctl set-mute @DEFAULT_SINK@ toggle"))

(defun audio-volume-message (volume)
  (message "Volume is now at ~A" (color-up "~D%" (round (* 100 volume)))))

(defco audio-volume-up () ()
  (audio-volume-message (audio-volume *volume-step*)))

(defco audio-volume-down () ()
  (audio-volume-message (audio-volume (- *volume-step*))))

(defco audio-toggle-mute () ()
  (multiple-value-bind (volume muted-p) (audio-toggle-mute*)
    (if muted-p
        (message "Audio ~A" (color-up "muted"))
        (audio-volume-message volume))))

(define-key *top-map* (kbd "XF86AudioRaiseVolume") "audio-volume-up")
(define-key *top-map* (kbd "XF86AudioLowerVolume") "audio-volume-down")
(define-key *top-map* (kbd "XF86AudioMute") "audio-toggle-mute")

;; * Keyboard
;; Low-level customization of the keyboard, and keybindings for applications.

(defun load-xmodmap ()
  (let ((xmodmap-file (merge-pathnames ".Xmodmap" (user-homedir-pathname))))
    (when (probe-file xmodmap-file)
      (sh
       "setxkbmap -layout fr -variant latin9 && xmodmap ~A"
       (namestring xmodmap-file)))))

(pushnew 'load-xmodmap *start-hook*)
(pushnew 'load-xmodmap *restart-hook*)

(defun display-keyseq (key seq cmd)
  (declare (ignore key))
  (unless (or (eq *top-map* *resize-map*) (stringp cmd))
    (message "~A" (print-key-seq (reverse seq)))))

(add-hook *key-press-hook* 'display-keyseq)

(set-prefix-key (kbd "s-c"))

(defkeys *top-map*
  ;; s-x resembles M-x in Emacs
  ("s-x" "colon")
  ("s-j" "next")
  ("s-k" "prev")
  ("s-RET" "rofi")
  ("s-SPC" "alacritty")
  ("s-TAB" "pull-hidden-other")
  ("Print" "screenshot")
  ("Sys_Req" "screenshot-area")
  ("s-J" "move-window-right")
  ("s-K" "move-window-left")
  ("s-ampersand" "pull 1")
  ("s-eacute" "pull 2")
  ("s-quotedbl" "pull 3")
  ("s-apostrophe" "pull 4")
  ("s-parenleft" "pull 5")
  ("s-minus" "pull 6")
  ("s-egrave" "pull 7")
  ("s-underscore" "pull 8")
  ("s-ccedilla" "pull 9")
  ("s-agrave" "pull 0"))

(defkeys *root-map*
  ("l" "lock-screen")
  ("m" "mode-line"))

;; * Bluetooth

;; TODO Work in progress. This works when Bluetooth is already on; later I'll
;; ensure it is on.

(defun bluetooth-make-device (device-string)
  "Make a Bluetooth device from a DEVICE-STRING.
DEVICE-STRINGs look like this: Device 11:22:33:44:55:66 NAME.
A Bluetooth device is a plist: (:mac MAC :name NAME)."
  (let ((components (uiop:split-string device-string :separator '(#\Space))))
    (list :mac  (second components)
          :name (format nil "~{~A~^ ~}" (cddr components)))))

(defun bluetooth-devices ()
  "Return a list of Bluetooth devices."
  (let ((device-strings
          (uiop:run-program '("bluetoothctl" "devices") :output :lines)))
    (mapcar #'bluetooth-make-device device-strings)))

(defun bluetooth-select-device ()
  "Return a Bluetooth device chosen from a selection menu."
  (flet ((device->str (d) (format nil "~A (~A)" (getf d :name) (getf d :mac))))
    (select-object-from-menu
     (current-screen) "Bluetooth devices:" (bluetooth-devices)
     :display-fn #'device->str)))

(defun bluetooth-device-connected-p (device)
  "Check if DEVICE is connected or not."
  (let ((info (uiop:run-program
               (list "bluetoothctl" "info" (getf device :mac))
               :output :string)))
    (not (null (search "Connected: yes" info)))))

(defun bluetooth-toggle-device* (device)
  "Toggle connection of Bluetooth DEVICE."
  (let ((command (if (bluetooth-device-connected-p device)
                     "disconnect"
                     "connect")))
    (sh "bluetoothctl ~A ~A" command (getf device :mac) :output t)))

(defcommand bluetooth-toggle-device () ()
  (let ((device (bluetooth-select-device)))
    (when device (bluetooth-toggle-device* device))))

;; * Experimental

(defvar *auto-clicker-process* nil)

(defcommand toggle-auto-clicker () ()
  (if *auto-clicker-process*
      (progn
        (sb-ext:process-kill *auto-clicker-process* 15)
        (setf *auto-clicker-process* nil)
        (message "Auto-clicker ~A" (color-down "OFF")))
      (progn
        (setf *auto-clicker-process*
              (sb-ext:run-program
               "/bin/sh"
               '("-c" "while :; do xdotool click 1; sleep 0.005; done")
               :search t
               :wait nil))
        (message "Auto-clicker ~A" (color-up "ON")))))

(define-key *root-map* (kbd "x") "toggle-auto-clicker")

;; * Emacs config

;;; Local Variables:
;;; eval: (progn
;;;         (put 'defcommand 'lisp-indent-function 'defun)
;;;         (put 'defco 'lisp-indent-function 'defun)
;;;         (font-lock-add-keywords
;;;          nil
;;;          '(("(\\(defcommand\\|defco\\)\\s-+\\(\\(?:\\sw\\|\\s_\\)+\\)"
;;;             (1 font-lock-keyword-face)
;;;             (2 font-lock-function-name-face)))))
;;; End:

(in-package #:stumpwm)

;; * Meta
;; Lisp stuff that helps playing with StumpWM itself but doesn't change the
;; experience yet.

;; ** Dependencies

;; An ASDF system might be cool in the future, overkill for now.
(ql:quickload '(:alexandria :slynk :local-time) :silent t)

;; ** Helpers

(defun sh (cmd) (run-shell-command cmd))

(defun sanitize-string (string)
  (string-trim
   '(#\Space #\Newline #\Backspace #\Tab #\Linefeed #\Page #\Return #\Rubout)
   string))

(defun sh/out (cmd) (sanitize-string (run-shell-command cmd t)))

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

;; ** Slynk

(defvar *slynk-server* nil)

(defco slynk-start () ()
  (unless *slynk-server*
    (setf *slynk-server* (slynk:create-server :port 4006 :dont-close t)))
  (message "Slynk server started."))

(defco slynk-stop () ()
  (when *slynk-server*
    (slynk:stop-server *slynk-server*)
    (setf *slynk-server* nil)
    (message "Slynk server stopped.")))

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
        "bat: %B | "
        (:eval (modeline-time))))

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
  (message "Color temperature is now ~DK." kelvin))

(defco redshift-set (kelvin) ((:number "Kelvin: "))
  (let ((k (alexandria:clamp (round kelvin) *redshift-min* *redshift-max*)))
    (setf *redshift-current* k)
    (sh (format nil "redshift -PO ~D" k))
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
    (sh (format nil "brightnessctl set ~D%" v))
    (message "Brightness is now at ~D%." v)
    v))

(defun brightness-shift (delta)
  (brightness-set (+ (or *brightness-current* 100) delta)))

(defco brightness-reset () () (brightness-set 100))

(defco brightness-decrease (&optional (step 5)) ()
  (brightness-shift (- step)))

(defco brightness-increase (&optional (step 5)) ()
  (brightness-shift step))

(defvar *night-mode-p* nil)

(defun night-mode-disable ()
  (redshift-reset)
  (brightness-reset)
  (setf *night-mode-p* nil)
  (message "Night mode disabled."))

(defun night-mode-enable ()
  (redshift-set *redshift-min*)
  (brightness-set 90)
  (setf *night-mode-p* t)
  (message "Night mode enabled."))

(defco night-mode-toggle () ()
  (if *night-mode-p*
      (night-mode-disable)
      (night-mode-enable)))

;; ** NordVPN

(defun nord-status ()
  (sh/out "nordvpn status"))

(defco nord-connect (&optional target) ((:string "Target: "))
  (if target
      (sh/out (format nil "nordvpn connect ~A" target))
      (sh/out "nordvpn connect france")))

(defun nord-disconnect ()
  (sh "nordvpn disconnect"))

;; ** screenshot

(defun do-screenshot (&optional area-p)
  (sh (if area-p
          "screenshot -s ~/tmp/screenshots/"
          "screenshot ~/tmp/screenshots/")))

(defco screenshot () ()
  (do-screenshot))

(defco screenshot-area () ()
  (do-screenshot t))

;; * Keyboard
;; Low-level customization of the keyboard, and keybindings for applications.

(defun load-xmodmap ()
  (let ((xmodmap-file (merge-pathnames ".Xmodmap" (user-homedir-pathname))))
    (when (probe-file xmodmap-file)
      (sh
       (format nil "setxkbmap -layout fr -variant latin9 && xmodmap ~A"
               (namestring xmodmap-file))))))

(pushnew 'load-xmodmap *start-hook*)
(pushnew 'load-xmodmap *restart-hook*)

(defun display-keyseq (key seq cmd)
  (declare (ignore key))
  (unless (or (eq *top-map* *resize-map*) (stringp cmd))
    (message "~A" (print-key-seq (reverse seq)))))

(add-hook *key-press-hook* 'display-keyseq)

(set-prefix-key (kbd "s-c"))

(defkeys *top-map*
  ("s-j" "next")
  ("s-k" "prev")
  ("s-RET" "rofi")
  ("s-SPC" "alacritty")
  ("s-TAB" "pull-hidden-other")
  ("Print" "screenshot")
  ("Sys_Req" "screenshot-area")
  ("s-J" "move-window-right")
  ("s-K" "move-window-left"))

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
    (sh/out (format nil "bluetoothctl ~A ~A" command (getf device :mac)))))

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
        (message "Auto-clicker OFF"))
      (progn
        (setf *auto-clicker-process*
              (sb-ext:run-program
               "/bin/sh"
               '("-c" "while :; do xdotool click 1; sleep 0.005; done")
               :search t
               :wait nil))
        (message "Auto-clicker ON"))))

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

(in-package #:net.lecigne.stumpwm)

;; * Meta
;; Lisp stuff that helps playing with StumpWM itself but doesn't change the
;; experience yet.

;; ** Helpers

;; TODO Hackish. Maybe use dedicated tools
(defun sh (control-str &rest args)
  "Run CONTROL-STR through FORMAT and execute it via StumpWM.
If the final arguments are :OUTPUT t, run synchronously and return sanitized
stdout; otherwise launch asynchronously."
  (let* ((output-arg-p (and (>= (length args) 2)
                            (eq (nth (- (length args) 2) args) :output)))
         (output-p (and output-arg-p (nth (- (length args) 1) args)))
         (fmt-args (if output-arg-p (butlast args 2) args))
         (cmd (if fmt-args
                  (apply #'format nil control-str fmt-args)
                  control-str)))
    (if output-p
        (core:sanitize-string (run-shell-command cmd t))
        (run-shell-command cmd))))

(defmacro aif (test then &optional else)
  "Anaphoric if."
  `(let ((it ,test))
     (if it ,then ,else)))

;; TODO Use a function, a macro doesn't bring much.
(defmacro defkeys (map &body bindings)
  (alexandria:with-gensyms (m)
    `(let ((,m ,map))
       ,@(loop for (key command) in bindings
               collect `(define-key ,m (kbd ,key) ,command)))))

;; (defun defkeys (map bindings)
;;   (dolist (binding bindings)
;;     (destructuring-bind (key command) binding
;;       (define-key map (kbd key) command))))

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
(setf stumpwm::*grab-pointer-foreground* (xlib:make-color :red 1 :green 0 :blue 0))
(setf stumpwm::*grab-pointer-background* (lookup-color (current-screen) "DeepSkyBlue"))
(setf stumpwm::*grab-pointer-character* 24)
(setf stumpwm::*grab-pointer-character-mask* 24)

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

(defco rofi-greenclip () ()
  (sh "rofi -modi \"clipboard:greenclip print\" -show clipboard"))

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

;; * Bluetooth

(defun bluetooth-select-device ()
  "Return a Bluetooth device chosen from a selection menu."
  (flet ((device->str (d) (format nil "~A (~A)" (getf d :name) (getf d :mac))))
    (select-object-from-menu
     (current-screen) "Bluetooth devices:" (bluetooth:devices)
     :display-fn #'device->str)))

(defco bluetooth-toggle-device () ()
  "Toggle the Bluetooth device selected from a menu."
  (let ((device (bluetooth-select-device)))
    (when device (bluetooth:toggle-device device))))

;; * Experimental

;; ** Auto-clicker

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

;; ** SomaFM
;; Quick and dirty wrapper for mpv + SomaFM (Drone Zone, for now).
;; https://somafm.com/

;; TODO - Move logic to dedicated SomaFM file
;;      - Create function to get a list of SomaFM channels
;;      - Use StumpWM menu to choose a channel
;;      - Use IPC with MPV (to get the currently playing track, for example)
;;      - Handle multiple players
;;      - Make it a CL lib later (at least provide a clean API)

(defvar *somafm-drone-zone-url* "https://somafm.com/m3u/dronezone130.m3u")
(defvar *somafm-player-program* "mpv")
(defvar *somafm-player-args* '("--no-video" "--force-window=no"))
(defvar *somafm-process* nil)

(defun somafm-player-command (url)
  (append (list *somafm-player-program*)
          *somafm-player-args*
          (list url)))

(defun somafm-reap-dead-process ()
  "If we still hold a dead process object, reap it and clear it."
  (when (and *somafm-process*
             (not (uiop:process-alive-p *somafm-process*)))
    (ignore-errors (uiop:wait-process *somafm-process*))
    (setf *somafm-process* nil)))

(defun somafm-running-p ()
  "True iff the managed player process is currently alive."
  (somafm-reap-dead-process)
  (and *somafm-process* (uiop:process-alive-p *somafm-process*)))

(defun somafm-start (url)
  "Start playback unless already running. Returns the process object or NIL."
  (unless (somafm-running-p)
    (setf *somafm-process*
          (uiop:launch-program (somafm-player-command url)
                               :output nil :error-output nil)))
  *somafm-process*)

(defun somafm-stop ()
  "Stop playback if running. Returns T if something was stopped."
  (when (somafm-running-p)
    (uiop:terminate-process *somafm-process*)
    (ignore-errors (uiop:wait-process *somafm-process*))
    (setf *somafm-process* nil)
    t))

(defun somafm-toggle (url)
  "Toggle playback for the managed SomaFM player."
  (if (somafm-running-p)
      (progn (somafm-stop) :stopped)
      (progn (somafm-start url) :started)))

(defcommand somafm-toggle-drone-zone () ()
  (case (somafm-toggle *somafm-drone-zone-url*)
    (:started (message "Starting SomaFM Drone Zone"))
    (:stopped (message "Stopped SomaFM"))))

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
    (message "~A" (stumpwm::print-key-seq (reverse seq)))))

(add-hook *key-press-hook* 'display-keyseq)

(set-prefix-key (kbd "s-c"))

(defvar *app-map* (make-sparse-keymap))

(defkeys *app-map*
  ("e" "emacs")
  ("f" "firefox")
  ("g" "gimp")
  ("t" "thunar"))

(defkeys *top-map*
  ;; Submaps
  ("s-a" '*app-map*)

  ;; Direct keybindings
  ("s-x" "colon") ; s-x resembles M-x in Emacs
  ("s-j" "next")
  ("s-k" "prev")
  ("s-RET" "rofi")
  ("s-S-RET" "rofi-greenclip")
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
;;; eval: (display-fill-column-indicator-mode)
;;; End:

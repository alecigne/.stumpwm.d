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

;; ** Logging

(stumpwm:redirect-all-output
 (merge-pathnames "stumpwm.log" stumpwm:*data-dir*))

;; I log with only one level, 0. That's enough for now.
(defun stump-debug (fmt &rest args)
  (apply #'stumpwm:dformat 0 (concatenate 'string fmt "~%") args))

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

(defun modeline-vpn ()
  (let ((status (vpn:current-status)))
    (case (vpn:vpn-status-state status)
      (:active
       (case (vpn:vpn-status-backend status)
         (:nordvpn "vpn: nord")
         (:wireguard
          (format nil "vpn: ~{~A~^,~}"
                  (vpn:vpn-status-interfaces status)))
         (otherwise "vpn: ?")))
      (:inactive "vpn: off")
      (otherwise "vpn: ?"))))

(setf *mode-line-timeout* 60)

(setf *screen-mode-line-format*
      '("[^B%g^b] %W^> "
        (:eval (modeline-vpn))
        " | "
        "bat: %B"
        " | "
        (:eval (modeline-time))))

(setf *group-format* "%n")

(when (and *initializing*
           (= (length (screen-groups (current-screen))) 1))
  (run-commands "gnewbg 2" "gnewbg 3" "gnewbg 4"))

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

;; `alttab' - The task switcher for minimalistic window managers.
;; https://github.com/sagb/alttab
(when *initializing*
  (if (member "alttab" (stumpwm:programs-in-path) :test #'string=)
      (run-shell-command "alttab &")
      (stump-debug "alttab not found in PATH")))

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

(defco pull-or-previous (number) ((:number "Window number: "))
  "Pull window NUMBER, or pull the previous hidden window when it is current."
  (let ((window (current-window)))
    (if (and window (= number (window-number window)))
        (pull-hidden-other)
        (pull-window-by-number number))))

;; * Applications

;; ** Usual suspects

(defco alacritty () () (sh "alacritty"))

(defco firefox () ()
  "Run or raise Firefox with a custom X11 window class. See [1].
[1] https://bugzilla.mozilla.org/show_bug.cgi?id=1747722"
  (run-or-raise "firefox-esr --class Firefox" '(:class "Firefox")))

(defco rofi () () (sh "rofi -show combi"))

(defco rofi-greenclip () ()
  (sh "rofi -modi \"clipboard:greenclip print\" -show clipboard"))

(defco thunar () () (sh "thunar"))

;; ** xsecurelock

(defco lock-screen () ()
  (sh "XSECURELOCK_PASSWORD_PROMPT=asterisks xsecurelock"))

;; ** Display

(defparameter *color-temperature-step* 500)

(defco color-temperature-status () ()
  (let ((kelvin (display:color-temperature-current)))
    (if kelvin
        (message "Color temperature is now ~A" (color-up "~DK" kelvin))
        (message "Color temperature is ~A" (color-warn "unknown")))
    kelvin))

(defco color-temperature-set (kelvin) ((:number "Kelvin: "))
  (display:color-temperature-set kelvin)
  (color-temperature-status))

(defun color-temperature-shift (delta)
  (display:color-temperature-shift delta)
  (color-temperature-status))

(defco color-temperature-reset () ()
  (display:color-temperature-reset)
  (color-temperature-status))

(defco color-temperature-warmer (&optional (step *color-temperature-step*)) ()
  (color-temperature-shift (- step)))

(defco color-temperature-cooler (&optional (step *color-temperature-step*)) ()
  (color-temperature-shift step))

(defco brightness-status () ()
  (let ((brightness (display:brightness-current)))
    (if brightness
        (message "Brightness is now ~A" (color-up "~D%" brightness))
        (message "Brightness is ~A" (color-warn "unknown")))
    brightness))

(defco brightness-set (value) ((:number "Value: "))
  (display:brightness-set value)
  (brightness-status))

(defun brightness-shift (delta)
  (display:brightness-shift delta)
  (brightness-status))

(defco brightness-reset () ()
  (display:brightness-reset)
  (brightness-status))

(defco brightness-decrease (&optional (step 5)) ()
  (brightness-shift (- step)))

(defco brightness-increase (&optional (step 5)) ()
  (brightness-shift step))

(defkeys *top-map*
  ("XF86MonBrightnessDown" "brightness-decrease")
  ("XF86MonBrightnessUp"   "brightness-increase"))

(defco night-mode-status () ()
  (let ((enabled-p (display:night-mode-p)))
    (message "Night mode ~A"
             (if enabled-p
                 (color-up "enabled")
                 (color-down "disabled")))
    enabled-p))

(defco night-mode () ()
  (display:night-mode)
  (night-mode-status))

;; ** NordVPN

(defco nord-connect (&optional target) ((:string))
  (unwind-protect
       (sh "nordvpn connect ~A" (aif target it "france") :output t)
    (vpn:invalidate-status-cache)))

(defco nord-disconnect () ()
  (unwind-protect
       (sh "nordvpn disconnect" :output t)
    (vpn:invalidate-status-cache)))

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

(defun audio-volume-message (volume)
  (message "Volume is now at ~A" (color-up "~D%" (round (* 100 volume)))))

(defco audio-volume-up () ()
  (audio-volume-message (sound:adjust-volume *volume-step*)))

(defco audio-volume-down () ()
  (audio-volume-message (sound:adjust-volume (- *volume-step*))))

(defco audio-toggle-mute () ()
  (multiple-value-bind (volume muted-p) (sound:toggle-mute)
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
  ("s-ampersand" "pull-or-previous 1")
  ("s-eacute" "pull-or-previous 2")
  ("s-quotedbl" "pull-or-previous 3")
  ("s-apostrophe" "pull-or-previous 4")
  ("s-parenleft" "pull-or-previous 5")
  ("s-minus" "pull-or-previous 6")
  ("s-egrave" "pull-or-previous 7")
  ("s-underscore" "pull-or-previous 8")
  ("s-ccedilla" "pull-or-previous 9")
  ("s-agrave" "pull-or-previous 0"))

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

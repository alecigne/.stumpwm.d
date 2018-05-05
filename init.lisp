(in-package :stumpwm)

(require :swank)

(swank-loader:init)

(defcommand swank () ()
  (setf *top-level-error-action* :break)
  (swank:create-server :port 4005
                       :style swank:*communication-style*
                       :dont-close t))

(swank)

(set-module-dir "~/.stumpwm.d/contrib")

(loop for module in '("battery-portable"
                      "cpu"
                      "mem"
                      "surfraw"
                      "ttf-fonts")
   do (load-module module))

(defcommand create-default-groups () ()
  (grename "main")
  (gnewbg-float "flt"))

(when *initializing*
  (create-default-groups))

(defcommand shell-command (command) ((:string "sh: "))
  "Run a shell command and display output to screen.
  This must be used in a functional side-effects-free style! If a program does not
  exit of its own accord, StumpWM might hang!"
  (check-type command string)
  (echo-string (current-screen)
               (run-shell-command command t)))

(defun show-key-seq (key seq val)
  (message (print-key-seq (reverse seq))))

(add-hook *key-press-hook* 'show-key-seq)

(xft:cache-fonts)
(set-font (make-instance 'xft:font :family "Source Code Pro" :subfamily "Regular" :size 10))

(setf *screen-mode-line-format*
      '("%g^n | "
        "^B%W^b^>"
        " BAT: %B | %c | %M | "
        (:eval (stumpwm:run-shell-command "date \"+%F w%V d%w %H:%M\"" t))))

(when (not (head-mode-line (current-head)))
  (toggle-mode-line (current-screen) (current-head)))

(setf *startup-message* "^5Lisp ^2^bsystem operational.")
(setf *suppress-frame-indicator* t)

(setf *mouse-focus-policy* :sloppy)

(setf *timeout-wait* 7)
(setf *window-name-source* :class)
(setf *maxsize-border-width* 1)
(setf *message-window-gravity* :bottom-right)
(setf *input-window-gravity* :bottom-right)

(setf *grab-pointer-foreground* (xlib:make-color :red 1 :green 0 :blue 0))
(setf *grab-pointer-background* (lookup-color (current-screen) "DeepSkyBlue"))
(setf *grab-pointer-character* 24)
(setf *grab-pointer-character-mask* 24)

(defcommand toggle-touchpad () ()
  "Toggle the laptop touchpad on/off."
  (let ((state (run-shell-command
                "synclient -l | grep TouchpadOff | awk '{ print $3 }'"
                t)))
    (case (string= (subseq state 0 1) "1")
      ((t) (progn (shell-command "synclient TouchpadOff=0")
                  (message "Touchpad is now on")))
      (otherwise (shell-command "synclient TouchpadOff=1")
                 (message "Touchpad is now off")))))

(defcommand gnome-terminal () ()
  "Run or raise gnome-terminal."
  (run-or-raise "dbus-launch gnome-terminal" '(:class "gnome-terminal")))

(defcommand firefox () ()
  "Run or raise Firefox."
  (run-or-raise "firefox" '(:class "Firefox")))

(defcommand wifi-list () ()
  "List of available wifi networks."
  (shell-command "nmcli dev wifi list"))

(defvar *redshift-color-temperature* 6500
  "Current screen color temperature.")

(defcommand redshift-change-color-temperature (amount)
    ((:number "Amount: "))
  "Changes the screen color temperature by AMOUNT."
  (incf *redshift-color-temperature* amount)
  (run-shell-command (format nil "redshift -O ~a" *redshift-color-temperature*))
  (message (format nil "Screen color temperature is now ~a" *redshift-color-temperature*)))

(defcommand redshift-reset-color-temperature () ()
  "Reset the screen color temperature to 6500."
  (redshift-change-color-temperature (- 6500 *redshift-color-temperature*)))

(defcommand translate-selection () ()
  (run-shell-command
   (format nil "firefox wordreference.com/enfr/~a" (get-x-selection))))

(defcommand print-screen-area (filename) ((:string "filename: "))
  (run-shell-command (format nil "import /home/alc/tmp/~a" filename)))

(defcommand show-uptime () ()
  "Show current uptime."
  (shell-command "uptime"))

(defmacro defkeys (map &rest couples)
  `(if ,map
       (progn ,@(loop for i in couples collect
                     `(define-key ,map (kbd ,(first i)) ,(second i))))
       (setf ,map
             (let ((map (make-sparse-keymap)))
               ,@(loop for i in couples collect
                      `(define-key map (kbd ,(first i)) ,(second i)))
               map))))

(defkeys *top-map*
  ("s-TAB" "pull-hidden-other")
  ("s-i" "iresize")
  ("s-k" "delete")
  ("s-m" "gmove")
  ("s-n" "next")
  ("s-p" "prev")
  ("s-s" "hsplit")
  ("s-S" "vsplit")
  ("s-o" "only")
  ("s-C-n" "number")
  ("s-ampersand" "pull 1")
  ("s-eacute" "pull 2")
  ("s-quotedbl" "pull 3")
  ("s-apostrophe" "pull 4")
  ("s-parenleft" "pull 5")
  ("s-minus" "pull 6")
  ("s-egrave" "pull 7")
  ("s-underscore" "pull 8")
  ("s-ccedilla" "pull 9")
  ("s-agrave" "pull 0")
  )

(defkeys *top-map*
  ("s-C" "gnew")
  ("s-C-C" "gnew-float")
  ("s-K" "gkill")
  ("s-N" "gnext")
  ("s-P" "gprev")
  ("s-ISO_Left_Tab" "gother") ; Super + Shift + Tab
  ("s-1" "gselect 1")
  ("s-2" "gselect 2")
  ("s-3" "gselect 3")
  ("s-4" "gselect 4")
  ("s-5" "gselect 5")
  ("s-6" "gselect 6")
  ("s-7" "gselect 7")
  ("s-8" "gselect 8")
  ("s-9" "gselect 9")
  )

(defkeys *top-map*
  ("s-F4" "redshift-change-color-temperature -250")
  ("s-F5" "redshift-change-color-temperature +250"))

(defkeys *top-map*
  ("s-SPC" "gnome-terminal")
  ("s-!" "exec")
  ("s-;" "colon")
  ("s-:" "eval")
  ("s-b" "banish")
  ("s-z" "mode-line")
  ("s-C-n" "number")
  )

(set-prefix-key (kbd "s-RET"))

(defkeys *root-map*
  ("a" '*applications-map*))

(defvar *applications-map* nil
  "Applications-related keybindings.")

(defkeys *applications-map*
  ("RET" "gnome-terminal")
  ("e" "emacs")
  ("f" "firefox")
  ("F" "firefox-no-remote")
  )

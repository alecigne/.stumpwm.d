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
      '("[^B%n^b] %W^> " (:eval (modeline-time))))

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
(setf *message-window-gravity* :bottom-right)
(setf *input-window-gravity* :bottom-right)
(setf *mode-line-position* :bottom)
(setf *grab-pointer-foreground* (xlib:make-color :red 1 :green 0 :blue 0))
(setf *grab-pointer-background* (lookup-color (current-screen) "DeepSkyBlue"))
(setf *grab-pointer-character* 24)
(setf *grab-pointer-character-mask* 24)
(sh "xsetroot -cursor_name left_ptr")

(setf *screen-mode-line-format*
      '("[^B%n^b] %W^>"
        (:eval (stumpwm:run-shell-command "date \"+%F w%V d%w %H:%M\"" t))))

;; * Appearance

(load-module "ttf-fonts")
(xft:cache-fonts)
(set-font (make-instance 'xft:font
                         :family "JetBrains Mono"
                         :subfamily "Regular"
                         :size 12
                         :antialias t))

;; * Applications

;; ** Usual suspects

(defco firefox () ()
  (run-or-raise "firefox-esr" '(:class "Firefox"))
  (message "Opening Firefox..."))

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

(defco redshift-night () ()
  (redshift-set *redshift-min*))

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

(set-prefix-key (kbd "s-c"))

(defkeys *top-map*
  ("s-j" "next")
  ("s-k" "prev")
  ("s-RET" "rofi")
  ("s-SPC" "alacritty")
  ("s-TAB" "pull-hidden-other")
  ("Print" "screenshot")
  ("Sys_Req" "screenshot-area"))

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
;;; End:

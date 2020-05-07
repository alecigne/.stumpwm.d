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

(load-module "ttf-fonts")

(xft:cache-fonts)
(set-font (make-instance 'xft:font :family "DejaVu Sans Mono" :subfamily "Book" :size 10))

(unless (head-mode-line (current-head))
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

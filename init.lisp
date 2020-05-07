(in-package :stumpwm)

(require :swank)

(swank-loader:init)

(defcommand swank () ()
  (setf *top-level-error-action* :break)
  (swank:create-server :port 4005
                       :style swank:*communication-style*
                       :dont-close t))

(swank)

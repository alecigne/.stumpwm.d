(in-package #:net.lecigne.stumpwm.core)

(defun sanitize-string (string)
  (string-trim
   '(#\Space #\Newline #\Backspace #\Tab #\Linefeed #\Page #\Return #\Rubout)
   string))

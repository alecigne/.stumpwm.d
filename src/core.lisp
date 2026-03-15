(defpackage #:stumpwm-config-core
  (:use #:cl)
  (:export #:sanitize-string))

(in-package #:stumpwm-config-core)

(defun sanitize-string (string)
  (string-trim
   '(#\Space #\Newline #\Backspace #\Tab #\Linefeed #\Page #\Return #\Rubout)
   string))

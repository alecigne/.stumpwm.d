(in-package #:net.lecigne.stumpwm.vpn)

;; * NordVPN

;; `nordvpn status' reports one of these:
;; Status: Connected / Status: Disconnected

;; Keep parsing separate from process execution so it can be tested directly.

(defun parse-nordvpn-status (output)
  (cond
    ((search "Status: Connected" output :test #'char-equal) :connected)
    ((search "Status: Disconnected" output :test #'char-equal) :disconnected)
    (t :unknown)))

;; Isolate subprocess execution behind a small boundary shared by the backend
;; detectors.

(defun run-command (command)
  (handler-case
      (multiple-value-bind (out err code)
          (uiop:run-program command
                            :force-shell nil
                            :output :string
                            :error-output :string
                            :ignore-error-status t)
        (values out err code :ran))
    (error ()
      (values "" "" nil :unavailable))))

;; Translate command availability and output into a backend-specific state.

(defun detect-nordvpn ()
  (multiple-value-bind (out err code availability)
      (run-command '("nordvpn" "status"))
    (declare (ignore err code))
    (if (eq availability :unavailable)
        :unavailable
        (parse-nordvpn-status out))))

;; Use a function-valued special variable as the test seam for detection.

(defparameter *nordvpn-detector* #'detect-nordvpn)

;; * WireGuard

;; Follow the same parsing, detection, and dependency-injection structure for
;; WireGuard.

(defun words (string)
  (remove ""
          (uiop:split-string string :separator '(#\Space #\Tab))
          :test #'string=))

(defun parse-wireguard-interfaces (output)
  (loop for line in (uiop:split-string output
                                       :separator '(#\Newline #\Return))
        for fields = (words line)
        when fields collect (first fields)))

(defun detect-wireguard ()
  (multiple-value-bind (out err code availability)
      (run-command '("ip" "-brief" "link" "show" "up" "type" "wireguard"))
    (declare (ignore err))
    (if (and (eq availability :ran) (zerop code))
        (values (parse-wireguard-interfaces out) :available)
        (values nil :unknown))))

(defparameter *wireguard-detector* #'detect-wireguard)

;; * VPN detection

;; Combine backend-specific results into one normalized public representation.

(defstruct (vpn-status
            (:constructor make-vpn-status (&key state backend interfaces)))
  "Normalized VPN state.
STATE is :ACTIVE, :INACTIVE, or :UNKNOWN. BACKEND is :NORDVPN,
:WIREGUARD, or NIL. INTERFACES contains active WireGuard interface names."
  state
  backend
  interfaces)

(defun detect-status ()
  (let ((nordvpn-state (funcall *nordvpn-detector*)))
    (if (eq nordvpn-state :connected)
        (make-vpn-status :state :active :backend :nordvpn)
        (multiple-value-bind (interfaces wireguard-state)
            (funcall *wireguard-detector*)
          (cond
            (interfaces
             (make-vpn-status :state :active
                              :backend :wireguard
                              :interfaces interfaces))
            ((or (eq nordvpn-state :unknown)
                 (eq wireguard-state :unknown))
             (make-vpn-status :state :unknown))
            (t
             (make-vpn-status :state :inactive)))))))

;; * Cached state

;; Keep raw detection behind a cache so frequent consumers remain inexpensive.

(defvar *cached-status* nil)
(defvar *cached-at* nil)

(defun invalidate-status-cache ()
  "Invalidate the cached VPN status."
  (setf *cached-status* nil
        *cached-at* nil)
  nil)

;; Use a monotonic clock so wall-clock adjustments cannot distort cache age.

(defun monotonic-seconds ()
  (/ (get-internal-real-time) internal-time-units-per-second))

(defparameter *clock* #'monotonic-seconds)

(defun refresh-status ()
  "Detect, cache, and return the current VPN status."
  (let ((status (detect-status)))
    (setf *cached-status* status
          *cached-at* (funcall *clock*))
    status))

;; CURRENT-STATUS is the main entry point for cached access and refresh.

(defparameter *status-cache-ttl* 60
  "Maximum age in seconds of a cached VPN status.")

(defun current-status ()
  "Return the VPN status, refreshing a cache older than *STATUS-CACHE-TTL*."
  (let ((now (funcall *clock*)))
    (if (and *cached-status*
             *cached-at*
             (< (- now *cached-at*) *status-cache-ttl*))
        *cached-status*
        (refresh-status))))

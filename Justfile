test:
    sbcl --non-interactive \
      --eval '(require :asdf)' \
      --eval '(asdf:test-system "stumpwm-config/tests")'

test:
    ros -e '(require :asdf)' \
      -e '(asdf:test-system "stumpwm-config/tests")' \
      -q

serve:
    silverbullet ./wiki

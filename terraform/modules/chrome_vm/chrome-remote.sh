#!/bin/bash

export DISPLAY=:99

if ! pgrep -f "Xvfb :99" >/dev/null; then
  Xvfb :99 -screen 0 1280x800x24 &
  sleep 2
fi

if ! pgrep -f "websockify.*6080" >/dev/null; then
  websockify --web=/usr/share/novnc/ 6080 localhost:5900 &
  sleep 2
fi

if ! pgrep -f "x11vnc.*:99" >/dev/null; then
  x11vnc -display :99 -rfbport 5900 -forever -nopw -shared &
  sleep 2
fi

chromium --no-sandbox --user-data-dir=/opt/chrome-profile

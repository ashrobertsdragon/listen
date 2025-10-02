#!/bin/bash
export DISPLAY=:99
EXTENSION_PATH="${extension_remote_path}"
PROFILE_DIR="/opt/chrome-profile"

cleanup() {
    pkill -f "google-chrome.*--load-extension" 2>/dev/null || true
    pkill -f "Xvfb :99" 2>/dev/null || true
    pkill -f "x11vnc" 2>/dev/null || true
    pkill -f "websockify" 2>/dev/null || true
}

trap cleanup EXIT

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

google-chrome \
  --display=:99 \
  --disable-gpu \
  --no-sandbox \
  --disable-dev-shm-usage \
  --disable-extensions-except="$EXTENSION_PATH" \
  --load-extension="$EXTENSION_PATH" \
  --disable-component-extensions-with-background-pages \
  --user-data-dir="$PROFILE_DIR" \
  --remote-debugging-port=9222 \
  --disable-features=Translate \
  --no-default-browser-check \
  --disable-background-timer-throttling \
  --disable-default-apps \
  --ash-no-nudges \
  --disable-search-engine-choice-screen \
  --autoplay-policy=user-gesture-required \
  --deny-permission-prompts \
  --disable-external-intent-requests \
  --noerrdialogs \
  --disable-notifications \
  --disable-features=MediaRouter \
  https://accounts.google.com &

CHROME_PID=$!

check_tabs_remaining() {
    local response
    response=$(curl -s http://localhost:9222/json/list 2>/dev/null)

    if [[ $? -eq 0 ]] && [[ -n "$response" ]]; then
        local active_tabs
        active_tabs=$(echo "$response" | jq '[.[] | select(.url | startswith("http"))] | length')
        echo "$active_tabs"
    else
        echo "0"
    fi
}

# Wait for Chrome to start
sleep 10


while kill -0 $CHROME_PID 2>/dev/null; do
    sleep 10
    
    TABS_REMAINING=$(check_tabs_remaining)
    
    if [[ "$TABS_REMAINING" -eq 0 ]]; then
        sleep 30
        TABS_REMAINING=$(check_tabs_remaining)
        if [[ "$TABS_REMAINING" -eq 0 ]]; then
            break
        fi
    fi
done

cleanup
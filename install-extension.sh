#!/bin/bash
set -e
apt-get update -y
apt-get install -y wget unzip

# Install Chrome + deps
apt-get install -y xvfb libnss3 libxss1 libappindicator3-1 \
  libindicator7 fonts-liberation libasound2 libatk-bridge2.0-0 \
  libatk1.0-0 libcups2 libgbm1 libgtk-3-0 libnspr4
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -y ./google-chrome-stable_current_amd64.deb

# Fetch extension
mkdir -p /opt/listen-extension
cd /opt/listen-extension
git clone https://github.com/ashrobertsdragon/listen.git .


# Start Chrome headless w/ extension
nohup Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99
google-chrome \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --remote-debugging-port=9222 \
  --load-extension=/opt/listen-extension \
  &

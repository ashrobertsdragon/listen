#!/bin/bash

export SSH_USER=${SSH_USER:-defaultuser}

sudo apt-get update
sudo apt-get install -y xvfb chromium chromium-driver novnc websockify x11vnc

sudo mkdir -p /opt/chrome-profile && sudo chown ${SSH_USER}:${SSH_USER} /opt/chrome-profile

sudo cp /tmp/chrome-remote.sh /opt/chrome-remote.sh
sudo chmod +x /opt/chrome-remote.sh

sudo tee /etc/systemd/system/chrome-remote.service > /dev/null <<'EOF'
[Unit]
Description=Chrome Remote Session
After=network.target
[Service]
Type=simple
User=${SSH_USER}
Environment=DISPLAY=:99
ExecStart=/opt/chrome-remote.sh
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable chrome-remote.service
sudo systemctl start chrome-remote.service

sudo chmod +x /tmp/patch-background.sh
sudo /tmp/patch-background.sh

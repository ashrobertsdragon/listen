#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y jq wget unzip xvfb libnss3 libxss1 \
  libappindicator3-1 libindicator7 fonts-liberation libasound2 \
  libatk-bridge2.0-0 libatk1.0-0 libcups2 libgbm1 libgtk-3-0 \
  libnspr4 novnc websockify x11vnc
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -y ./google-chrome-stable_current_amd64.deb

sudo mkdir -p /opt/chrome-profile && sudo chown ${SSH_USER}:${SSH_USER} /opt/chrome-profile

sudo mkdir -p ${extension_remote_path} && sudo chown ${SSH_USER}:${SSH_USER} ${extension_remote_path}
git clone https://github.com/ashrobertsdragon/listen.git
cp listen/listen-listener ${extension_remote_path}
sudo rm -rf listen

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
Environment=extension_remote_path=${extension_remote_path}
ExecStart=/opt/chrome-remote.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/chrome-periodic.timer > /dev/null <<EOF
[Unit]
Description=Run Chrome Session Every ${period}
Requires=chrome-remote.service

[Timer]
OnBootSec=10min
OnUnitActiveSec=${period}
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable chrome-periodic.timer
sudo systemctl start chrome-periodic.timer

cat > ${extension_remote_path}/config.json << EOF
{
  "endpoint": "${upload_function_url}?key=${api_key}",
  "tabGroupName": "listen"
}
EOF

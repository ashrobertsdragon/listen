#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

sudo -E apt-get update -y
sudo -E apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  git jq wget unzip xvfb novnc websockify x11vnc

wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo -E apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  libnss3 libxss1 libappindicator3-1 libindicator7 fonts-liberation libasound2 \
  libatk-bridge2.0-0 libatk1.0-0 libcups2 libgbm1 libgtk-3-0 libnspr4
sudo -E dpkg -i google-chrome-stable_current_amd64.deb || sudo -E apt-get install -f -y
rm -f google-chrome-stable_current_amd64.deb

sudo mkdir -p /opt/chrome-profile
sudo chown ${SSH_USER}:${SSH_USER} /opt/chrome-profile

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
OnBootSec=5min
OnUnitActiveSec=${period}
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable chrome-remote.service
sudo systemctl enable chrome-periodic.timer
sudo systemctl start chrome-remote.service
sudo systemctl start chrome-periodic.timer
echo "Startup script completed at $(date)" >> /var/log/startup.log

cat > ${extension_remote_path}/config.json << EOF
{
  "endpoint": "${upload_function_url}?key=${api_key}",
  "tabGroupName": "listen"
}
EOF

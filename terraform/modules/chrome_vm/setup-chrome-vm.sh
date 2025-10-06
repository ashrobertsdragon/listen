#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends git wget xvfb x11vnc websockify novnc jq python3 python3-pip python3-venv

wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg -i google-chrome-stable_current_amd64.deb || apt-get install -f -y --no-install-recommends
rm -f google-chrome-stable_current_amd64.deb

mkdir -p /opt/chrome-profile
chown ${SSH_USER}:${SSH_USER} /opt/chrome-profile

mkdir -p /etc/opt/chrome/policies/managed
cat > /etc/opt/chrome/policies/managed/sync_policy.json << 'EOF'
{
  "SyncDisabled": false,
  "SyncTypesListDisabled": [
    "bookmarks",
    "extensions",
    "apps",
    "themes",
    "passwords",
    "autofill",
    "preferences",
    "readingList"
  ]
}
EOF
chown -R ${SSH_USER}:${SSH_USER} /opt/chrome-profile

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

python3 -m venv /opt/queue-venv
/opt/queue-venv/bin/pip install requests websocket-client

sudo tee /etc/systemd/system/queue-processor.service > /dev/null <<EOF
[Unit]
Description=URL Queue Processor
After=network.target chrome-remote.service
Requires=chrome-remote.service

[Service]
Type=simple
User=${SSH_USER}
Environment=SUPABASE_URL=${supabase_url}
Environment=SUPABASE_KEY=${supabase_key}
Environment=UPLOAD_ENDPOINT=${upload_function_url}
ExecStart=/opt/queue-venv/bin/python3 /opt/queue_processor.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable chrome-remote.service
sudo systemctl enable chrome-periodic.timer
sudo systemctl enable queue-processor.service
sudo systemctl start chrome-remote.service
sudo systemctl start chrome-periodic.timer
sudo systemctl start queue-processor.service
echo "Startup script completed at $(date)" >> /var/log/startup.log

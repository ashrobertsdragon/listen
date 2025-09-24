#!/usr/bin/env bash
set -euo pipefail
SSH_USER="${SSH_USER}"
VM_IP="${VM_IP}"
SSH_KEY="${SSH_PRIVATE_KEY_FILE}"

echo "Connecting to Chrome VM at $VM_IP"
echo "Using SSH key: $SSH_KEY"
echo "Cleaning up old host keys..."
ssh-keygen -f ~/.ssh/known_hosts -R "$VM_IP" 2>/dev/null || true
echo "Starting SSH tunnel on port 6080..."

cleanup_host_key() {
    echo "Cleaning up host key..."
    ssh-keygen -f ~/.ssh/known_hosts -R "$VM_IP" 2>/dev/null || true
}
trap cleanup_host_key EXIT

(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=~/.ssh/known_hosts -N -L 6080:localhost:6080 "${SSH_USER}@${VM_IP}" & PID=$!)
sleep 3

echo "SSH tunnel established."
xdg-open "http://localhost:6080/vnc.html"
echo "Press Ctrl+C to disconnect"

wait $PID
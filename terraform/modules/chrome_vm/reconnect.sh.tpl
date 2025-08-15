#!/usr/bin/env bash
set -euo pipefail
SSH_USER="${SSH_USER}"
VM_IP="${VM_IP}"
(ssh -o StrictHostKeyChecking=no -N -L 6080:localhost:6080 "${SSH_USER}@${VM_IP}" & PID=$!)
sleep 3
xdg-open "http://localhost:6080/vnc.html"
wait $PID
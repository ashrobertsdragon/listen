#!/usr/bin/env bash
set -euo pipefail
SSH_USER="${SSH_USER:-your_ssh_user}"
VM_IP=$(terraform output -raw chrome_vm_ip)
(ssh -o StrictHostKeyChecking=no -N -L 6080:localhost:6080 "${SSH_USER}@${VM_IP}" & PID=$!)
sleep 3
xdg-open "http://localhost:6080/vnc.html"
wait $PID

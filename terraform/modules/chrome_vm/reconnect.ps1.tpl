#!/usr/bin/env pwsh
$SSH_USER = "${SSH_USER}"
$VM_IP = "${VM_IP}"
$SSH_KEY = "${SSH_PRIVATE_KEY_FILE}"
$VM_CREATED = "${VM_CREATED}"

Write-Host "Connecting to Chrome VM at $VM_IP"

$vmAge = (Get-Date) - [DateTime]::Parse($VM_CREATED)
if ($vmAge.TotalMinutes -lt 5) {
    $remainingMinutes = [math]::Ceiling(5 - $vmAge.TotalMinutes)
    Write-Host "⚠️  WARNING: VM was created $([math]::Floor($vmAge.TotalMinutes)) minutes ago." -ForegroundColor Yellow
    Write-Host "⚠️  The startup script needs ~5 minutes to install packages." -ForegroundColor Yellow
    Write-Host "⚠️  Please wait approximately $remainingMinutes more minute(s) before connecting." -ForegroundColor Yellow
    Write-Host ""
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Exiting. Try again in a few minutes."
        exit 0
    }
}

Write-Host "Using SSH key: $SSH_KEY"
Write-Host "Cleaning up old host keys..."
ssh-keygen -f "$env:USERPROFILE\.ssh\known_hosts" -R "$VM_IP" 2>$null
Write-Host "Starting SSH tunnel on port 6080..."

$sshProcess = Start-Process -FilePath "ssh" -ArgumentList @(
    "-i", $SSH_KEY,
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=$env:USERPROFILE\.ssh\known_hosts",
    "-N",
    "-L", "6080:localhost:6080",
    "$SSH_USER@$VM_IP"
) -NoNewWindow -PassThru

Start-Sleep -Seconds 3

Write-Host "SSH tunnel established."
Write-Host "Opening VNC in your default browser..."

Start-Process "http://localhost:6080/vnc.html"

Write-Host "Press Ctrl+C to disconnect"


try {
    $sshProcess.WaitForExit()
}
finally {
    if (!$sshProcess.HasExited) {
        $sshProcess.Kill()
    }
    Write-Host "Cleaning up host key..."
    ssh-keygen -f "$env:USERPROFILE\.ssh\known_hosts" -R "$VM_IP" 2>$null
}
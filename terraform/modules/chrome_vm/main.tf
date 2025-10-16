resource "google_compute_instance" "chrome_vm" {
  name         = "chrome-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_file)
    host        = self.network_interface[0].access_config[0].nat_ip
    timeout     = "2m"
  }

  provisioner "file" {
    source      = "${path.module}/chrome-remote.sh"
    destination = "/tmp/chrome-remote.sh"
  }

  provisioner "file" {
    source      = "${path.root}/../listen-listener"
    destination = "/tmp/listen-listener"
  }

  provisioner "file" {
    source      = "${path.root}/../vm/queue_processor.py"
    destination = "/tmp/queue_processor.py"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cp /tmp/chrome-remote.sh /opt/chrome-remote.sh",
      "sudo chmod +x /opt/chrome-remote.sh",
      "sudo cp /tmp/queue_processor.py /opt/queue_processor.py",
      "sudo mkdir -p ${var.extension_remote_path}",
      "sudo cp -r /tmp/listen-listener/* ${var.extension_remote_path}/ 2>/dev/null || echo 'Using git clone fallback'",
      "if [ ! -f ${var.extension_remote_path}/manifest.json ]; then git clone https://github.com/ashrobertsdragon/listen.git /tmp/repo && sudo cp -r /tmp/repo/listen-listener/* ${var.extension_remote_path}/ && rm -rf /tmp/repo; fi",
      "sudo chown -R ${var.ssh_user}:${var.ssh_user} ${var.extension_remote_path}",
      "cat > /tmp/config.json << 'CONFIGEOF'\n{\"supabaseUrl\": \"${var.supabase_url}\", \"supabaseKey\": \"${var.supabase_key}\", \"tabGroupName\": \"listen\"}\nCONFIGEOF",
      "sudo mv /tmp/config.json ${var.extension_remote_path}/config.json",
      "sudo chown ${var.ssh_user}:${var.ssh_user} ${var.extension_remote_path}/config.json",
      "ls -la ${var.extension_remote_path}/"
    ]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_file)}"
    startup-script = templatefile("${path.module}/setup-chrome-vm.sh", {
      upload_function_url   = var.upload_function_url
      supabase_url          = var.supabase_url
      supabase_key          = var.supabase_key
      SSH_USER              = var.ssh_user
      extension_remote_path = var.extension_remote_path
      period                = var.period
    })
  }

  tags = ["chrome-vm"]
}

resource "local_file" "reconnect_script" {
  content = templatefile("${path.module}/reconnect.${var.windows ? "ps1" : "sh"}.tpl", {
    SSH_USER             = var.ssh_user
    VM_IP                = google_compute_instance.chrome_vm.network_interface[0].access_config[0].nat_ip
    SSH_PRIVATE_KEY_FILE = var.ssh_private_key_file
    VM_CREATED           = google_compute_instance.chrome_vm.creation_timestamp
  })
  filename        = "${path.root}/reconnect.${var.windows ? "ps1" : "sh"}"
  file_permission = "0755"
}

resource "terraform_data" "cleanup_host_key" {
  input = {
    vm_ip   = google_compute_instance.chrome_vm.network_interface[0].access_config[0].nat_ip
    windows = var.windows
  }

  provisioner "local-exec" {
    when        = destroy
    command     = self.input.windows ? "ssh-keygen -f \"%USERPROFILE%\\.ssh\\known_hosts\" -R \"${self.input.vm_ip}\" 2>nul || echo done" : "ssh-keygen -f ~/.ssh/known_hosts -R '${self.input.vm_ip}' 2>/dev/null || true"
    interpreter = self.input.windows ? ["cmd", "/c"] : ["bash", "-c"]
  }
}

resource "local_file" "desktop_config" {
  content = templatefile("${path.module}/desktop-config.json.tpl", {
    SUPABASE_URL = var.supabase_url
    SUPABASE_KEY = var.supabase_key
  })
  filename        = "${path.root}/../listen-listener/desktop-config.json"
  file_permission = "0644"
}

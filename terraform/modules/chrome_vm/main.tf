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
    source      = "${path.module}chrome-remote.sh"
    destination = "/tmp/chrome-remote.sh"
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_file)}"
    startup-script = templatefile("${path.module}/setup-chrome-vm.sh", {
      upload_function_url = var.upload_function_url
      api_key = var.api_key
      SSH_USER = var.ssh_user
      extension_remote_path = var.extension_remote_path
      period = var.period
    })
  }

  tags = ["chrome-vm"]
}

resource "local_file" "reconnect_script" {
  content = templatefile("${path.module}/reconnect.sh.tpl", {
    SSH_USER = var.ssh_user
    VM_IP    = google_compute_instance.chrome_vm.network_interface[0].access_config[0].nat_ip
  })
  filename = "${path.root}/reconnect.sh"
  file_permission = "0755"
}
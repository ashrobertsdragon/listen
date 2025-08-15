resource "google_compute_instance" "chrome_vm" {
  name         = "chrome-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key)}"
  }

  provisioner "file" {
    source      = "chrome-remote.sh"
    destination = "/tmp/chrome-remote.sh"
  }

  provisioner "file" {
    source      = "patch-background.sh"
    destination = "/tmp/patch-background.sh"
  }

  provisioner "file" {
    source      = "setup-chrome-vm.sh"
    destination = "/tmp/setup-chrome-vm.sh"
  }

  # Install packages and create systemd service; patching background.js uses the provided URL
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/setup-chrome-vm.sh",
      "sudo /tmp/setup-chrome-vm.sh"
    ]
  }
}

output "chrome_vm_ip" {
  value = google_compute_instance.chrome_vm.network_interface[0].access_config[0].nat_ip
}

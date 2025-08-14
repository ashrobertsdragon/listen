output "chrome_vm_ip" {
  value = google_compute_instance.chrome_vm.network_interface[0].access_config[0].nat_ip
}

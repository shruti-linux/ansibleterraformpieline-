terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.48.0"
    }
  }

  backend "gcs" {
    bucket      = "shruti-bucket-llove"
    prefix      = "terraform/state"
    credentials = "/tmp/sa.json"
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
  credentials = var.credentials_file
}

resource "google_compute_network" "vpc" {
  name                    = "ansible-vpc"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "8080", "1000-2000"]
  }

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ansible-target"]
  priority      = 1000
  description   = "Allow SSH and other ports from anywhere"
}

resource "google_compute_instance" "ansible_vm" {
  name         = "ansible-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = google_compute_network.vpc.name
    access_config {}  # Enables public IP
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    useradd -m -s /bin/bash devops
    mkdir -p /home/devops/.ssh
    echo "${file(var.public_key_path)}" > /home/devops/.ssh/authorized_keys
    chown -R devops:devops /home/devops/.ssh
    chmod 700 /home/devops/.ssh
    chmod 600 /home/devops/.ssh/authorized_keys
    echo 'devops ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/devops
    chmod 440 /etc/sudoers.d/devops
  EOT

  tags = ["ansible-target"]
}

output "instance_ip" {
  value = google_compute_instance.ansible_vm.network_interface[0].access_config[0].nat_ip
}

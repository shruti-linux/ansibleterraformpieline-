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
    prefix      = "ansibleterraform"
    credentials = "/root/sa.json"
  }
}

provider "google" { 
  project     = "ansi-465711" 
  region      = "us-central1" 
  zone        = "us-central1-a" 
  credentials = "/root/sa.json"
}

resource "google_compute_network" "vpc" {
  name                    = "centos9-vpc1"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "8080", "1000-2000"]
  }

  direction = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  target_tags = ["centos9"]
  priority    = 1000
  description = "Allow SSH from anywhere"
}

resource "google_compute_instance" "centos9_vm" {
  depends_on = [google_compute_firewall.allow_ssh]
  name         = "centos9-vm2"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-stream-9"
    }
  }

  network_interface {
    network = google_compute_network.vpc.name
    access_config {}
  }

  metadata = {
    ssh-keys = "centos:${file("~/.ssh/id_rsa.pub")}"
  }

  metadata_startup_script = <<-EOT
      #!/bin/bash
      useradd -m -s /bin/bash devops
      mkdir -p /home/devops/.ssh
      echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBsHIxxTGG1KDFVHB3020cQcViPE72XjfIgfPchK9xJHpXmSWsh9YcmXeuZdV7le7Dm2B0srqusUmwc5UzJFt1EeG3xw1SrxGfFziimhPV8xhox3Y9aft2h31lTkQg9lFoPJ8RU6vxgNr6xkRdgRD1GXj7imVZu9XKcJXcQI8DI9PY/nEuLh7k4SZ4gERNqvZjoouZzMLBkhISDOlnPR46a9SwkvM7Rm4ob1W/B8Zoo8hOPvD58JtDyaZd4d0mZmE6R1GolAyFJKhn1x4sUSYhXc9cv/P4+3HKp1I01aFKzqKiC3jD0SUDNHTSVfDJ84NneBsmKdR05NrLdDp37yYLBZZsKlZ9jHXA16ioQwNs6FsaCDb2QsQz67WqUTX7jTuyR3EV8lVq5nkljo15UcDPqPuE9k3t1fTGbBuEY0J+Sa6Z9EpQwfDaqKDlIHyXpgEdhmqpdzQXgm4HcvjgogiZiJdpQcpxZRKLCMxns8NLGpkl70HRCRB/SrxZPnb9KdWbYekssI4/CMUcbtQRjDTvDjH3WnavMKVhJ1bMIYaVQGJ/gZ4XxTCRNafweHKU13SdyM0mRlZ1mgAGIvUtpzk0gt9NWUnTWZm7BbT0MbcpadRyDjDFozNMxEAgFbq+S0Gf31YCWyJTFd5FA4dOgEdSgXOmN9aT07yvHIaYYIeewQ== eduarnofficial@gcpvm-github-terraform-ansible-centos9" > /home/devops/.ssh/authorized_keys
      chown -R devops:devops /home/devops/.ssh
      chmod 700 /home/devops/.ssh
      chmod 600 /home/devops/.ssh/authorized_keys
    
      echo 'devops ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/devops
      chmod 440 /etc/sudoers.d/devops
  EOT

  tags = ["centos9"]
}

output "instance_ip" {
  value = google_compute_instance.centos9_vm.network_interface[0].access_config[0].nat_ip
}

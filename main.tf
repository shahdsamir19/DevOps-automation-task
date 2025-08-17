# main.tf

provider "google" {
  project = "durable-destiny-4653"  # Replace with your GCP project ID
  region  = "us-central1"      # Replace with your desired region
  zone    = "us-central1-a"    # Replace with your desired zone
}

# Create a VPC network
resource "google_compute_network" "vpc" {
  name                    = "my-vpc"
  auto_create_subnetworks = false
}

# Create a subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "my-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
}

# Create a firewall rule to allow SSH (port 22)
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]  # Restrict this in production for security
}

# Create the CICD machine instance
resource "google_compute_instance" "cicd" {
  name         = "cicd-machine"
  machine_type = "e2-medium"  # Adjust as needed
  zone         = "us-central1-a"
  tags = ["cicd"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"  # Ubuntu 20.04 LTS
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {}  # Assigns a public IP
  }

  # Add your SSH public key here for access
  metadata = {
    ssh-keys = "terraform:${file("~/.ssh/id_rsa.pub")}"  # Replace with your SSH key
  }
}

# Create the Production machine instance
resource "google_compute_instance" "production" {
  name         = "production-machine"
  machine_type = "e2-medium"  # Adjust as needed
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"  # Ubuntu 20.04 LTS
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {}  # Assigns a public IP
  }

  # Add your SSH public key here for access
  metadata = {
    ssh-keys = "terraform:${file("~/.ssh/id_rsa.pub")}"  # Replace with your SSH key
  }
}

# Null resource to provision CICD machine with Ansible
resource "null_resource" "provision_cicd" {
  triggers = {
    instance_id = google_compute_instance.cicd.id
  }

 provisioner "local-exec" {
    command = <<EOT
      sleep 30  # Wait for instance to be ready
      ansible-playbook -i '${google_compute_instance.cicd.network_interface[0].access_config[0].nat_ip},' \
        --user seed --private-key ~/.ssh/id_rsa \
        --ssh-extra-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        --extra-vars "install_jenkins=true" ansible/playbook.yml
    EOT
  }
}

# Null resource to provision Production machine with Ansible
resource "null_resource" "provision_production" {
  triggers = {
    instance_id = google_compute_instance.production.id
  }

  provisioner "local-exec" {
    command = <<EOT
      sleep 30  # Wait for instance to be ready
      ansible-playbook -i '${google_compute_instance.production.network_interface[0].access_config[0].nat_ip},' \
        --user seed --private-key ~/.ssh/id_rsa \
        --ssh-extra-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        --extra-vars "install_jenkins=false" ansible/playbook.yml
    EOT
  }
}
resource "google_compute_firewall" "allow_jenkins" {
  name    = "allow-jenkins"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["8080" , "443", "80"]
  }

  source_ranges = ["0.0.0.0/0"]  # Restrict this
  target_tags   = ["cicd"]
}
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]  # Restrict this
  target_tags   = ["cicd"]
}
output "cicd_public_ip" {
  value = google_compute_instance.cicd.network_interface[0].access_config[0].nat_ip
}

output "production_public_ip" {
  value = google_compute_instance.production.network_interface[0].access_config[0].nat_ip
}
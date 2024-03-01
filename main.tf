locals {
  project_id       = "copelcicd"
  region           = "us-central1"
  network          = "default"
  image            = "debian-12-bookworm-v20240213"
  ssh_user         = "ivan"
  private_key_path = "~/gitlab-ce-mount/ivankey"
  ssh-keys         = "ivan:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7QfP2cCVq98FIEfrahlMUnBUW8KlF4Cs6twE4NZ6SWtkbBtW/UPE/oyAceFaBPsvADCG+jPXOhjfW/jeOBF/hBYdgGX2igXJF+Lg0AW4+Fi97KY4s+WhA4tEaUxVGuGi+r28sIAcsmi8Rgs5eiMZSt7EPVchqjNL8hqCidcwNLIFON8Zi1UUqjdlIwCYwW3EYCWYLPcZaH/D3n5IT0DSvMq2ZTSNR5B8b/ORGex9vsQQ06iALz5FrOsTLajKnaFTcNlfu5g/OPxEc/1Q63uz368KlLCVieeTCuRP0RkGsTUFDfPSU6zTGeVj4LYDtlQ3sbDj0n8bsbduWhKUmQprH ivan"
}

provider "google" {
  project = local.project_id
  region  = local.region
}

resource "google_service_account" "gitlab-ce-sa" {
  account_id = "gitlab-ce-sa"
}

resource "google_compute_firewall" "gitlab-ce-http-access" {
  name    = "gitlab-ce-http-access"
  network = local.network

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges           = ["0.0.0.0/0"]
  target_service_accounts = [google_service_account.gitlab-ce-sa.email]
}

resource "google_compute_firewall" "gitlab-ce-https-access" {
  name    = "gitlab-ce-https-access"
  network = local.network

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges           = ["0.0.0.0/0"]
  target_service_accounts = [google_service_account.gitlab-ce-sa.email]
}

resource "google_compute_firewall" "gitlab-ce-https-8443-access" {
  name    = "gitlab-ce-https-8443-access"
  network = local.network

  allow {
    protocol = "tcp"
    ports    = ["8443"]
  }

  source_ranges           = ["0.0.0.0/0"]
  target_service_accounts = [google_service_account.gitlab-ce-sa.email]
}

resource "google_compute_instance" "gitlab-instance" {
  name         = "gitlab-ce"
  machine_type = "e2-micro"
  zone         = "us-central1-c"

  boot_disk {
    initialize_params {
      image = local.image
    }
  }

  network_interface {
    network = local.network
    access_config {}
  }

  service_account {
    email  = google_service_account.gitlab-ce-sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = local.ssh-keys
  }

  #provisioner "remote-exec" {
  #  inline = [
  #    "curl -s https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash"
  #  ]

  #  connection {
  #    type        = "ssh"
  #    user        = local.ssh_user
  #    private_key = file(local.private_key_path)
  #    host        = google_compute_instance.gitlab-instance.network_interface.0.access_config.0.nat_ip
  #  }
  #}

}

output "ssh-connection" {
  value = "ssh -i ${local.private_key_path} ${local.ssh_user}@${google_compute_instance.gitlab-instance.network_interface.0.access_config.0.nat_ip}"
}

output "execute-playbook" {
  value = "ansible-playbook -i ${google_compute_instance.gitlab-instance.network_interface.0.access_config.0.nat_ip}, --private-key ${local.private_key_path} install-gitlab-ce.yaml -u ${local.ssh_user}"
}

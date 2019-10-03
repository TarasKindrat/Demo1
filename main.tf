// Configure the Google Cloud provider

provider "google" {
  credentials = var.credentials
  project     = var.project
  region      = var.region
}



resource "google_compute_instance" "teamcity-ci" {
  name         = "teamcity-ci"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["teamcity-ci"]

  # definition of the boot disk - the initial image 
  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }

  network_interface {
    network            = var.network
    subnetwork         = var.subnetwork
    subnetwork_project = var.subnetwork_project
    network_ip         = var.network_ip

    access_config {
            nat_ip  = var.nat_ip
    }
  }
  
  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.public_key_path)}"
  }

}

resource "google_compute_firewall" "allow-teamcity-ci-http" {
  name        = "allow-teamcity-ci-http"
  network     = var.network
  target_tags = ["teamcity-ci"]

  allow {
    protocol = "tcp"
    ports    = ["8111"]
  }

  allow {
    protocol = "icmp"
  }
}

resource "null_resource" "teamcity_prov" {
 
# connection for the work of service providers after installing and configuring the OS
  connection {
    host        = "${google_compute_instance.teamcity-ci.network_interface.0.access_config.0.nat_ip}"
    type        = "ssh"
    user        = "${var.ssh_user}"
    agent       = false
    private_key = "${file(var.private_key_path)}"
  }
# Copy bash script to teamcity instance 
  provisioner "file" {
    source      = "./files/teamcity_install.sh"
    destination = "/tmp/teamcity_install.sh" 
 } 
 # Copy credential key to teamcity for deploy from there infrastructure by terraform
 provisioner "file" {
    source      = "./DevOps/DevOps1.json"
    destination ="/tmp/keys/DevOps1.json"
 }
 # Copy ssh keys to teamcity for connection to test web server 
 provisioner "file" {
    source      = "./DevOps/.ssh/authorized_keys"
    destination ="/tmp/keys/.ssh/authorized_keys"
 } 
provisioner "file" {
    source      = "./DevOps/.ssh/id_rsa"
    destination ="/tmp/keys/.ssh/id_rsa"
 } 
 provisioner "file" {
    source      = "./DevOps/.ssh/id_rsa.pub"
    destination ="/tmp/keys/.ssh/id_rsa.pub"
 }  

  provisioner "remote-exec" {
  
    inline = [
      "sudo chmod +x /tmp/teamcity_install.sh",
      "sudo /bin/bash /tmp/teamcity_install.sh "
    ]
  }
}



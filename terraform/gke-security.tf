provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "primary" {
  name     = "secure-cluster"
  location = var.region

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable Binary Authorization
  enable_binary_authorization = true

  # Enable Network Policy
  network_policy {
    enabled = true
    provider = "CALICO"
  }

  # Enable Shielded Nodes
  node_config {
    shielded_instance_config {
      enable_secure_boot = true
    }
  }

  # Enable Private Cluster
  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.0/28"
  }

  # Enable Master Authorized Networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = var.authorized_network
      display_name = "Authorized Network"
    }
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "zero-day-cluster"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location          = var.region
  initial_node_count = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Enable Binary Authorization
  enable_binary_authorization = true

  # Enable Network Policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Enable Shielded Nodes
  node_config {
    shielded_instance_config {
      enable_secure_boot = true
    }
    
    # Use Spot instances for cost optimization
    spot = true

    # Enable Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # Enable Private Cluster
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.0/28"
  }

  # Enable Master Authorized Networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.0/8"
      display_name = "Internal"
    }
  }

  # Enable cluster autoscaling
  cluster_autoscaling {
    enabled = true
    resource_limits {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 10
    }
    resource_limits {
      resource_type = "memory"
      minimum       = 2
      maximum       = 20
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = "2023-01-01T00:00:00Z"
      end_time   = "2023-01-02T00:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  vertical_pod_autoscaling {
    enabled = true
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "zero-day-rg"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "zero-day-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "zeroday"

  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size            = "Standard_D2s_v3"
    enable_auto_scaling = true
    min_count          = 1
    max_count          = 5
    
    # Use spot instances for cost optimization
    priority        = "Spot"
    eviction_policy = "Delete"
    spot_max_price  = -1 # Use current spot price
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "calico"
  }

  # Enable pod identity
  pod_identity_profile {
    enabled = true
  }

  # Enable monitoring
  monitor_metrics {
    annotations_allowed = ["*"]
    labels_allowed     = ["*"]
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed = true
    azure_rbac_enabled = true
  }

  # Enable auto-upgrade
  automatic_channel_upgrade = "stable"

  # Enable node auto-repair
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [22, 23, 0, 1, 2, 3]
    }
  }

  tags = {
    Environment = "Production"
    Project     = "zero-day-framework"
  }
}

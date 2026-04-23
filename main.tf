terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Le groupe de ressources principal
resource "azurerm_resource_group" "rg" {
  name     = "RG-FINAL-BECHARD"
  location = "Canada Central"
}

# 1. VNet HUB (Pour Bastion et Gateway)
resource "azurerm_virtual_network" "vnet_hub" {
  name                = "VNet-Hub"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Sous-réseau pour le Bastion (Nom obligatoire dans Azure)
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 2. VNet SPOKE (Pour AKS)
resource "azurerm_virtual_network" "vnet_app" {
  name                = "VNet-App"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "Subnet-AKS"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet_app.name
  address_prefixes     = ["10.1.1.0/24"]
}

# 3. PEERING (La liaison entre les deux réseaux)
resource "azurerm_virtual_network_peering" "hub_to_app" {
  name                         = "Hub-To-App"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_app.id
  allow_virtual_network_access = true
}

# Création du cluster AKS
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "Bechard-AKS-Cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "bechard-k8s"

  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = "Standard_B2s" # 2 vCPUs - Idéal pour ton quota
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 1 # On bloque à 1 pour ne pas dépasser ton quota de 4
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }
}

# Sortie pour récupérer la commande de connexion
output "client_certificate" {
  value     = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
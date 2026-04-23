// Paramètres de base
param location string = resourceGroup().location
param clusterName string = 'Bechard-AKS-Cluster'

// 1. VNet App (Déjà existant via Terraform, mais on le référence ici)
// Note: Si tu as déjà exécuté Terraform, on va juste déployer AKS dedans.
resource vnetApp 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: 'VNet-App'
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' existing = {
  parent: vnetApp
  name: 'Subnet-AKS'
}

// 2. Déploiement du Cluster AKS (Version Bicep)
resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: 'bechard-k8s'
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: 1
        vmSize: 'Standard_B2s_v2' // Correction ici pour Canada Central
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: aksSubnet.id
        enableAutoScaling: false // On reste à 1 pour protéger ton quota de 4 vCPUs
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
    }
  }
}

// 3. Azure SQL (Pour la base de données demandée)
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: 'server-sql-bechard-final'
  location: location
  properties: {
    administratorLogin: 'bechardadmin'
    administratorLoginPassword: 'Password123456!' // À changer plus tard
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: 'ecomdb'
  location: location
  sku: {
    name: 'Basic' // Economique pour l'optimisation des coûts
  }
}

output aksName string = aks.name

// 4. Compte de Stockage (Nom raccourci pour respecter la limite de 24 caractères)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: take('stbech${uniqueString(resourceGroup().id)}', 24) 
  location: location
  sku: {
    name: 'Standard_LRS' // Économique
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// Conteneur pour les fichiers (ex: photos des produits)
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/appfiles'
}

// 5. Azure Container Registry (Pour stocker tes images Docker)
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acrbechardfinal'
  location: location
  sku: {
    name: 'Basic' // Le moins cher, parfait pour un projet
  }
  properties: {
    adminUserEnabled: true
  }
}

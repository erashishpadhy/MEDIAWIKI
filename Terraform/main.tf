provider "azurerm" {
  features {}
}

## Creating resource group
resource "azurerm_resource_group" "rg" {
  name     = "Mytest-poc"
  location = "eastus2"
}

## Creating Vnet
resource "azurerm_virtual_network" "vnet" {
  name                = "MyVnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
  dns_servers         = ["10.0.0.4", "10.0.0.5"]
}

##Create Subnet
resource "azurerm_subnet" "subnet" {
  name                                          = "MySubnet"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = ["10.1.1.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

## Creating Mysql Seerver

resource "azurerm_mariadb_server" "maria_server" {
  name                              = "mediawikidb"
  location                          = azurerm_resource_group.rg.location
  resource_group_name               = azurerm_resource_group.rg.name
  administrator_login               = "manager"
  administrator_login_password      = "Redhat@12345"
  sku_name                          = "GP_Gen5_2"
  storage_mb                        = 5120
  version                           = "10.2"
  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  
}

resource "azurerm_mariadb_database" "example" {
  name                = "mediawiki_mariadb_database"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mariadb_server.maria_server.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}


## Creating Complete private service_endpoints


# Create a DB Private DNS Zone
resource "azurerm_private_dns_zone" "private-endpoint-dns-private-zone" {
  name                = "privatelink.mariadb.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}


# Create Private Endpoint

resource "azurerm_private_endpoint" "private-endpoint" {
  name                 = "Mydbserver_ep"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  subnet_id            = azurerm_subnet.subnet.id
  private_service_connection {
    name                           = "Mydbserver_ep.privateEndpoint"
    private_connection_resource_id = azurerm_mariadb_server.maria_server.id
    subresource_names              = ["mariadbServer"]
    is_manual_connection           = false
 }
  
  private_dns_zone_group {
    name = "${azurerm_resource_group.rg.name}_${replace("privatelink.mysql.database.azure.com", ".", "_")}"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.private-endpoint-dns-private-zone.id
    ]
  }
  depends_on = [
    azurerm_private_dns_zone.private-endpoint-dns-private-zone
  ]
}

# DB Private Endpoint Connecton
data "azurerm_private_endpoint_connection" "private-endpoint-connection" {
  name                = azurerm_private_endpoint.private-endpoint.name
  resource_group_name = azurerm_resource_group.rg.name
  depends_on = [
    azurerm_private_endpoint.private-endpoint
  ]
}

# Create a Private DNS to VNET link
resource "azurerm_private_dns_zone_virtual_network_link" "dns-zone-to-vnet-link" {
  name                  = "Mydbserver_ep-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.private-endpoint-dns-private-zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

##Output
output "subnet_id" {
  value = azurerm_subnet.subnet.id
}
output "subnet" {
  value = azurerm_subnet.subnet
}


### Creating Cluster
resource "azurerm_kubernetes_cluster" "Myaks" {
  name                  = "${azurerm_resource_group.rg.name}-aks"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  dns_prefix            = "${azurerm_resource_group.rg.name}-aks"
  kubernetes_version    = "1.20.7"
  
  default_node_pool {
    name                    = "default"
    vnet_subnet_id          = azurerm_subnet.subnet.id
    enable_auto_scaling     = false
    node_count              = 2
    vm_size                 = "Standard_D2_v2"
    enable_node_public_ip   = false
    }
  
  network_profile {
        network_plugin     = "azure"
        load_balancer_sku  = "standard"
        network_policy     = "azure"
    }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control {
    enabled = true
  }

}

resource "azurerm_container_registry" "acr" {
  name                = "Mytestpocacracr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"
  admin_enabled       = false
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.Myaks.kube_config.0.client_certificate
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.Myaks.kube_config_raw

  sensitive = true
}

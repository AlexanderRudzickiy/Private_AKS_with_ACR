# Create a new resource group for the spoke
resource "azurerm_resource_group" "spoke_rg" {
  name     = var.spoke_resource_group_name
  location = var.spoke_resource_group_location
}

# Create spoke virtual network
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = var.spoke_vnet
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  address_space       = var.spoke_vnet_address_space
}

#Create peering from spoke_vnet to hub_vnet
resource "azurerm_virtual_network_peering" "spoke_vnet_to_hub" {
  name                         = "${azurerm_virtual_network.spoke_vnet.name}-to-${var.hub_vnet_name}"
  resource_group_name          = azurerm_resource_group.spoke_rg.name
  virtual_network_name         = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id    = var.remote_virtual_network_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Create peering from hub_vnet to spoke_vnet
resource "azurerm_virtual_network_peering" "hub_to_spoke_vnet" {
  name                         = "${var.hub_vnet_name}-to-${azurerm_virtual_network.spoke_vnet.name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Create subnet for AKS
resource "azurerm_subnet" "aks_subnet" {
  name                 = "AKSSubnet"
  resource_group_name  = azurerm_resource_group.spoke_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = var.aks_subnet_address_prefix
}

# Create PE subnet
resource "azurerm_subnet" "pe_subnet" {
  name                 = "PESubnet"
  resource_group_name  = azurerm_resource_group.spoke_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = var.pe_subnet_address_prefix
}

# Create route table for AKS and PE subnets
resource "azurerm_route_table" "aks_route_table" {
  name                = "aks-route-table"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
}

# Define udr to route traffic through the Azure Firewall
resource "azurerm_route" "aks_route" {
  name                   = "route-to-azfw"
  resource_group_name    = azurerm_resource_group.spoke_rg.name
  route_table_name       = azurerm_route_table.aks_route_table.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.azurerm_firewall_ip
}

# Associate route table with VNG subnet
resource "azurerm_subnet_route_table_association" "aks_route_association_1" {
  subnet_id      = azurerm_subnet.aks_subnet.id 
  route_table_id = azurerm_route_table.aks_route_table.id
}

# Associate route table with PE subnet
resource "azurerm_subnet_route_table_association" "aks_route_association_2" {
  subnet_id      = azurerm_subnet.pe_subnet.id 
  route_table_id = azurerm_route_table.aks_route_table.id
}

resource "azurerm_container_registry" "acr" {
  name                          = "AzureContainerRegistry"
  resource_group_name           = azurerm_resource_group.spoke_rg.name
  location                      = azurerm_resource_group.spoke_rg.location
  sku                           = "Premium"
  admin_enabled                 = true
  public_network_access_enabled = false
}

resource "azurerm_private_dns_zone" "acr_pdns_zone" {
  name                = var.acr_private_dns_zone
  resource_group_name = azurerm_resource_group.spoke_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "plink_acr_spoke" {
  name                  = "acr_dns_link_spoke"
  resource_group_name   = azurerm_resource_group.spoke_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_pdns_zone.name
  virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "plink_acr_hub" {
  name                  = "acr_dns_link_hub"
  resource_group_name   = azurerm_resource_group.spoke_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_pdns_zone.name
  virtual_network_id    = var.remote_virtual_network_id
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-acr"
  location            = azurerm_resource_group.spoke_rg.location
  resource_group_name = azurerm_resource_group.spoke_rg.name
  subnet_id           = azurerm_subnet.pe_subnet.id

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-private-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr_pdns_zone.id]
  }
}

resource "azurerm_private_dns_zone" "aks" {
  name                = var.aks_private_dns_zone
  resource_group_name = azurerm_resource_group.spoke_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "plink_aks_spoke" {
  name                  = "aks_dns_link_spoke"
  resource_group_name   = azurerm_resource_group.spoke_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "plink_aks_hub" {
  name                  = "aks_dns_link_hub"
  resource_group_name   = azurerm_resource_group.spoke_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = var.remote_virtual_network_id
}

### Identity
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks"
  resource_group_name = azurerm_resource_group.spoke_rg.name
  location            = azurerm_resource_group.spoke_rg.location
}

resource "azurerm_user_assigned_identity" "pod" {
  name                = "id-pod"
  resource_group_name = azurerm_resource_group.spoke_rg.name
  location            = azurerm_resource_group.spoke_rg.location
}

### Identity role assignment
resource "azurerm_role_assignment" "dns_contributor" {
  scope                = azurerm_private_dns_zone.aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "network_contributor" {
  scope                = azurerm_virtual_network.spoke_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "aks_custom_route_table" {
  scope                = azurerm_route_table.aks_route_table.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

### AKS cluster creation
resource "azurerm_kubernetes_cluster" "aks" {
  name                       = "private-aks-cluster"
  location                   = azurerm_resource_group.spoke_rg.location
  resource_group_name        = azurerm_resource_group.spoke_rg.name
  dns_prefix_private_cluster = "private-aks-cluster"
  private_cluster_enabled    = true
  private_dns_zone_id        = azurerm_private_dns_zone.aks.id

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  network_profile {
    network_plugin     = "azure"
    outbound_type = "userDefinedRouting"
  }

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
    max_pods       = 20
  }

  depends_on = [
    azurerm_role_assignment.network_contributor,
    azurerm_role_assignment.dns_contributor,
    azurerm_role_assignment.aks_custom_route_table
  ]
}

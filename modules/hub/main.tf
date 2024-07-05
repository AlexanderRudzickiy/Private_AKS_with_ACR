# Create a new resource group for the hub
resource "azurerm_resource_group" "hub_rg" {
  name     = var.hub_resource_group_name
  location = var.hub_resource_group_location
}

# Create public IP prefix
resource "azurerm_public_ip_prefix" "pip_prefix" {
  name                = "${azurerm_resource_group.hub_rg.name}-pip-prefix"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku                 = "Standard"
  prefix_length       = 31
}

# Create Hub virtual network
resource "azurerm_virtual_network" "hub_vnet" {
  name                = var.hub_vnet_name
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  address_space       = var.hub_vnet_address_space
}

# Create subnet for Azure Firewall
resource "azurerm_subnet" "azfw_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = var.azfw_subnet_address_prefix
}

# Create Azure DevOps subnet
resource "azurerm_subnet" "devops_subnet" {
  name                 = "DevOpsSubnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = var.devops_subnet_address_prefix
}

# Create VNG subnet
resource "azurerm_subnet" "vng_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub_rg.name
  virtual_network_name = azurerm_virtual_network.hub_vnet.name
  address_prefixes     = var.vng_subnet_address_prefix
}

# Create public IP addresses for Azure Firewall
resource "azurerm_public_ip" "pip_azfw" {
  name                = "pip-azfw"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku                 = "Standard"
  allocation_method   = "Static"
}

# Create Azure Firewall policy
resource "azurerm_firewall_policy" "azfw_policy" {

  name                     = "azfw-policy"
  resource_group_name      = azurerm_resource_group.hub_rg.name
  location                 = azurerm_resource_group.hub_rg.location
  sku                      = var.firewall_sku_tier
  threat_intelligence_mode = "Alert"

  dns {
    proxy_enabled = true # Option that allows AZFW to be Azure DNS forwarder
  }
}

# Create Azure Firewall
resource "azurerm_firewall" "fw" {
  name                = "AzureFirewall"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier

  ip_configuration {
    name                 = "azfw-ipconfig"
    subnet_id            = azurerm_subnet.azfw_subnet.id
    public_ip_address_id = azurerm_public_ip.pip_azfw.id
  }

  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
}

# Allow outbound traffic from AKS subnet 
resource "azurerm_firewall_policy_rule_collection_group" "policy_rule_collection_group" {
  name               = "DefaultCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
  priority           = 300
  network_rule_collection {
    name     = "DefaultNetworkRuleCollection"
    action   = "Allow"
    priority = 400
    rule {
      name                  = "DefaultOutbound"
      protocols             = ["Any"]
      source_addresses      = [var.internal_addresses]
      destination_ports     = ["*"]
      destination_addresses = ["*"]
    }
    rule {
      name                  = "AllowAccessFromVPN"
      protocols             = ["Any"]
      source_addresses      = [var.vpn_client_ips]
      destination_ports     = ["*"]
      destination_addresses = ["*"]
    }
  }
}

resource "azurerm_public_ip" "vng_public_ip" {
  name                = "pip-vng"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name

  allocation_method = "Dynamic"
}

# Create Azure Virtual Network Gateway with P2S configuration
resource "azurerm_virtual_network_gateway" "vng" {
  name                = var.hub_vng_name
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "Basic"
  enable_bgp          = false
  active_active       = false

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vng_public_ip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vng_subnet.id
  }

  vpn_client_configuration {
    address_space = [var.vpn_client_ips]


    root_certificate {
      name             = var.root_certificate_name
      public_cert_data = var.public_cert_data
    }
  }
}

# Create route table 
resource "azurerm_route_table" "hub_route_table" {
  name                = "${azurerm_virtual_network.hub_vnet.name}-route-table"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name
}

# Define UDR to route traffic through the Azure Firewall
resource "azurerm_route" "vng_route" {
  name                   = "route-to-azfw"
  resource_group_name    = azurerm_resource_group.hub_rg.name
  route_table_name       = azurerm_route_table.hub_route_table.name
  address_prefix         = var.internal_addresses
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
}

# Associate route table with VNG subnet
resource "azurerm_subnet_route_table_association" "vng_route_association" {
  subnet_id      = azurerm_subnet.vng_subnet.id
  route_table_id = azurerm_route_table.hub_route_table.id
}

# Associate route table with DevOps subnet
resource "azurerm_subnet_route_table_association" "devops_route_association" {
  subnet_id      = azurerm_subnet.devops_subnet.id
  route_table_id = azurerm_route_table.hub_route_table.id
}

# Create network interface for Azure DevOps VM
resource "azurerm_network_interface" "devops_vm_nic" {
  name                = "${var.devops_vm_name}-nic"
  location            = azurerm_resource_group.hub_rg.location
  resource_group_name = azurerm_resource_group.hub_rg.name

  ip_configuration {
    name                          = "${var.devops_vm_name}-ip"
    subnet_id                     = azurerm_subnet.devops_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual machine
resource "azurerm_windows_virtual_machine" "devops_vm" {
  name                = var.devops_vm_name
  resource_group_name = azurerm_resource_group.hub_rg.name
  location            = azurerm_resource_group.hub_rg.location
  size                = "Standard_D2s_v3" #needed for nested virtualization (Docker)
  admin_username      = "${var.devops_vm_name}-admin"
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.devops_vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-11"
    sku       = "win11-22h2-ent"
    version   = "latest"
  }

  provision_vm_agent = true
}

module "hub_module" {
  source                       = "./modules/hub"
  hub_resource_group_location  = "israelcentral"
  hub_resource_group_name      = "hub-rg"
  hub_vnet_name                = "hub-vnet"
  hub_vnet_address_space       = ["10.0.0.0/16"]
  azfw_subnet_address_prefix   = ["10.0.1.0/24"]
  vng_subnet_address_prefix    = ["10.0.2.0/24"]
  devops_subnet_address_prefix = ["10.0.3.0/24"]
  devops_vm_name               = "DevOps-VM"
  admin_password               = var.admin_password
  internal_addresses           = "10.0.0.0/8" #Used to allow access from and to AKS spoke
  vpn_client_ips               = "10.2.0.0/24"
  firewall_sku_tier            = "Standard"
  hub_vng_name                 = "hub-vng"
  root_certificate_name        = "P2SRootCert"
  public_cert_data             = var.public_cert_data
}

module "spokes_module" {
  source                        = "./modules/spokes"
  spoke_resource_group_location = "israelcentral"
  spoke_resource_group_name     = "spoke-aks-rg"
  spoke_vnet                    = "spoke-vnet"
  spoke_vnet_address_space      = ["10.10.0.0/16"]
  remote_virtual_network_id     = module.hub_module.vnet_id
  hub_resource_group_name       = module.hub_module.hub_rg_name
  hub_vnet_name                 = module.hub_module.hub_vnet_name
  aks_subnet_address_prefix     = ["10.10.0.0/22"]
  pe_subnet_address_prefix      = ["10.10.4.0/24"]
  azurerm_firewall_ip           = module.hub_module.private_ip_address
  aks_private_dns_zone          = "privatelink.israelcentral.azmk8s.io"
  acr_private_dns_zone          = "privatelink.azurecr.io"
  node_count                    = "1"
}

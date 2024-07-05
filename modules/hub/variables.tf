# Define variables
variable "hub_resource_group_name" {
  description = "Name of the hub resource group"
  type        = string
}

variable "hub_resource_group_location" {
  description = "Localtion of the hub resource group"
  type =    string
}

variable "devops_vm_name" {
  description = "Name of the DevOps VM"
  type = string
}

variable "hub_vnet_name" {
  description = "Name of the Azure Firewall virtual network"
  type        = string
}

variable "hub_vnet_address_space" {
  description = "Address space of the Azure Firewall virtual network"
  type        = list(string)
}

variable "azfw_subnet_address_prefix" {
  description = "Address prefix for the Azure Firewall subnet"
  type        = list(string)
}

variable "firewall_sku_tier" {
  description = "SKU tier for the Azure Firewall"
  type        = string
}

variable "vng_subnet_address_prefix" {
  description = "Address prefix for the Azure Firewall subnet"
  type        = list(string)
}

variable "hub_vng_name" {
  description = "Hub VNG name" 
  type = string
}

variable "public_cert_data" {
  type = string
  description = "Public certificate data"
  sensitive = true
}

variable "root_certificate_name" {
type = string
}


variable "vpn_client_ips" {
    type = string
}


variable "internal_addresses" {
}

variable "devops_subnet_address_prefix" {
  type = list(string)
}

variable "admin_password" {
  type = string
}
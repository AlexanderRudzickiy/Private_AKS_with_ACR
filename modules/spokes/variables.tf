# Define variables
variable "spoke_resource_group_name" {
  description = "Name of the hub resource group"
  type        = string
}

variable "spoke_resource_group_location" {
  description = "Localtion of the hub resource group"
  type =    string
}

variable "spoke_vnet" {
  description = "Name of the Azure Firewall virtual network"
  type        = string
}

variable "spoke_vnet_address_space" {
  description = "Address space of the Azure Firewall virtual network"
  type        = list(string)
}

variable "remote_virtual_network_id" {
  type = string
}

variable "hub_resource_group_name" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "aks_subnet_address_prefix" {
    type = list(string)
}


variable "pe_subnet_address_prefix" {
  type = list(string)
}

variable "azurerm_firewall_ip" {
  type = string
}

variable "node_count" {
  type = string
}

variable "aks_private_dns_zone" {
  type = string
}

variable "acr_private_dns_zone" {
  type = string
}
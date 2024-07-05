output "private_ip_address" {
  description = "Specifies the private IP address of the firewall."
  value = azurerm_firewall.fw.ip_configuration[0].private_ip_address
}

output "vnet_id" {
  description = "Specifies the Hub Vnet id."
  value = azurerm_virtual_network.hub_vnet.id
}

output "hub_vnet_name" {
  description = "Specifies the Hub Vnet name."
  value = azurerm_virtual_network.hub_vnet.name
}

output "hub_rg_name" {
  description = "Specifies the Hub RG name."
  value = azurerm_resource_group.hub_rg.name
}
resource "azurerm_container_registry" "lab_acr" {
  name                          = local.container_registry_name
  resource_group_name           = azurerm_resource_group.lab_resource_group.name
  location                      = azurerm_resource_group.lab_resource_group.location
  sku                           = "Standard"
  admin_enabled                 = true
  public_network_access_enabled = true
  anonymous_pull_enabled        = true
  tags                          = local.common_tags
}

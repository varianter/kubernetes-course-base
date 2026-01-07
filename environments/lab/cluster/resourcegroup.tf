resource "azurerm_resource_group" "lab_resource_group" {
  name     = "rg-${local.workload_name}-${local.environment}-${local.location_short}"
  location = local.location

  tags = local.common_tags
}

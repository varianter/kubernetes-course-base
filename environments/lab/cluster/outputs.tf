# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "resource_group_name" {
  value = azurerm_resource_group.lab_resource_group.name
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.default.name
}

output "container_registry_login_server" {
  description = "The login server for the container registry."
  value       = azurerm_container_registry.lab_acr.login_server
}

output "container_registry_admin_username" {
  description = "The admin username for the container registry."
  value       = azurerm_container_registry.lab_acr.admin_username
}

output "container_registry_admin_password" {
  description = "The admin password for the container registry."
  value       = azurerm_container_registry.lab_acr.admin_password
  sensitive   = true
}

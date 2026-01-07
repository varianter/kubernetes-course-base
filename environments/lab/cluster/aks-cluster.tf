# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.workload_name}-${local.environment}-${local.location_short}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.lab_resource_group.location
  resource_group_name = azurerm_resource_group.lab_resource_group.name
  tags                = local.common_tags
}

# create the subnet
resource "azurerm_subnet" "aks" {
  name                 = "snet-${local.workload_name}-${local.environment}-${local.location_short}"
  resource_group_name  = azurerm_resource_group.lab_resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_kubernetes_cluster" "default" {
  name                = "aks-${local.workload_name}-${local.environment}-${local.location_short}"
  location            = azurerm_resource_group.lab_resource_group.location
  resource_group_name = azurerm_resource_group.lab_resource_group.name
  dns_prefix          = "aks-${local.workload_name}-${local.environment}-${local.location_short}"
  kubernetes_version  = "1.34.0"
  oidc_issuer_enabled = true
  tags                = local.common_tags

  default_node_pool {
    name       = "default"
    node_count = local.node_pool_count
    # Important comment regarding vm_size, from official TF docs:
    # temporary_name_for_rotation must be specified when attempting a resize.
    # E.g. vm_size set to temporary_name_for_rotation first, then applied, then the new size.
    vm_size         = local.node_pool_vm_size
    vnet_subnet_id  = azurerm_subnet.aks.id
    max_pods        = local.node_pool_max_pods
    os_disk_size_gb = 30
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    type = "SystemAssigned"
  }

  local_account_disabled = false

  role_based_access_control_enabled = false

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }
}

# secure it
resource "azurerm_network_security_group" "aks" {
  name     = "nsg-${local.workload_name}-${local.environment}-${local.location_short}"
  location = azurerm_resource_group.lab_resource_group.location

  # TODO: Do not allow all IP-addresses
  security_rule {
    name                       = "${azurerm_kubernetes_cluster.default.name}-security_rule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  resource_group_name = azurerm_kubernetes_cluster.default.resource_group_name
  tags                = local.common_tags
}

# create a public IP for the LB
resource "azurerm_public_ip" "public_lb" {
  name                = "pip-${local.workload_name}-${local.environment}-${local.location_short}"
  location            = azurerm_resource_group.lab_resource_group.location
  resource_group_name = azurerm_kubernetes_cluster.default.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
  depends_on          = [azurerm_kubernetes_cluster.default]
}

resource "kubernetes_namespace" "lab" {
  metadata {
    name = "lab"
  }
  depends_on = [azurerm_kubernetes_cluster.default]
}

# ConfigMap with cluster-wide configuration values
resource "kubernetes_config_map" "cluster_config" {
  metadata {
    name      = "cluster-config"
    namespace = "argocd"
  }

  data = {
    tenantId = data.azurerm_client_config.current.tenant_id
  }

  depends_on = [kubernetes_namespace.argocd]
}

resource "azurerm_dns_a_record" "variantdev_wildcard_record" {
  name                = "*.dev"
  zone_name           = azurerm_dns_zone.cluster_dns_zone.name
  resource_group_name = azurerm_dns_zone.cluster_dns_zone.resource_group_name
  ttl                 = 300
  records             = [data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].ip]

  depends_on = [helm_release.ingress_nginx]
}

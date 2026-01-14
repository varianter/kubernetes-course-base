locals {
  environment           = "lab"
  location              = "North Europe"
  location_short        = "northeurope"
  location_abbreviation = "ne"
  common_tags = {
    environment = local.environment
    repository  = local.repository_url
    location    = local.location_short
  }

  argocd_subdomain_name = "argocd"


  workload_name = "platform"
  # Pay attention to the below node_pool variables. To allow for 110 pods, we need at least Standard_D2as_v4 VM size.
  node_pool_vm_size               = "Standard_B2s"
  node_pool_count                 = 1
  node_pool_max_pods              = 60
  repository_url                  = ""
  letsencrypt_cert_cluster_issuer = "letsencrypt-lab"

  cluster_domain = "${local.cluster_subdomain_name}.${local.cluster_dns_zone_name}"
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 0.14"
}

provider "azurerm" {
  alias                           = "internetjenester"
  resource_provider_registrations = "none"
  subscription_id                 = local.subscription_id
  tenant_id                       = local.tenant_id
  use_oidc                        = true
  use_cli                         = true
  features {}
}

# Provider for DNS zone (can be in different subscription)
provider "azurerm" {
  alias           = "dns"
  subscription_id = local.cluster_dns_zone_subscription_id
  tenant_id       = local.tenant_id
  use_cli         = true
  features {}
}

provider "azurerm" {
  subscription_id = local.subscription_id
  tenant_id       = local.tenant_id
  use_cli         = true
  features {}
}

provider "azuread" {
  tenant_id = local.tenant_id
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.default.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.default.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.default.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.default.kube_config.0.cluster_ca_certificate)
  load_config_file       = false
}


data "azurerm_client_config" "current" {}


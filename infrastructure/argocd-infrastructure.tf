# ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [azurerm_kubernetes_cluster.default]
}

locals {
  argocd_domain_name = "${local.argocd_subdomain_name}.${local.cluster_subdomain_name}.${local.cluster_dns_zone_name}"
}

# ArgoCD Helm Release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.0"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  wait       = true

  values = [
    yamlencode({
      global = {
        domain = local.argocd_domain_name
      }

      configs = {
        params = {
          "server.insecure" = true
        }

        cm = {
          "url" = local.argocd_domain_name
        }
      }

      server = {
        ingress = {
          enabled          = true
          ingressClassName = local.default_ingress_classname
          annotations = {
            "cert-manager.io/cluster-issuer"               = local.letsencrypt_cert_cluster_issuer
            "nginx.ingress.kubernetes.io/ssl-redirect"     = "true"
            "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
          }
          hosts = [local.argocd_domain_name]
          tls = [{
            secretName = "argocd-tls"
            hosts      = [local.argocd_domain_name]
          }]
        }

        extraArgs = [
          "--insecure"
        ]
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.ingress_nginx,
    helm_release.cert_manager,
  ]
}

# DNS zone (from external resource group/subscription)
data "azurerm_dns_zone" "cluster_dns_zone" {
  provider            = azurerm.dns
  name                = local.cluster_dns_zone_name
  resource_group_name = local.cluster_dns_zone_resource_group
}

resource "azurerm_dns_a_record" "argocd" {
  provider            = azurerm.dns
  name                = "${local.argocd_subdomain_name}.${local.cluster_subdomain_name}"
  zone_name           = data.azurerm_dns_zone.cluster_dns_zone.name
  resource_group_name = data.azurerm_dns_zone.cluster_dns_zone.resource_group_name
  ttl                 = 300
  records             = [data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].ip]
  depends_on          = [helm_release.ingress_nginx]
}

# Get the nginx ingress LoadBalancer IP
data "kubernetes_service" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [helm_release.ingress_nginx]
}

# ArgoCD Repository Connection for infrastructure-as-code
resource "kubectl_manifest" "argocd_repo_infrastructure" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "repo-infrastructure-as-code"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
    }
    stringData = {
      type    = "git"
      url     = local.github_repo_url
      project = "default"
    }
  })

  depends_on = [
    helm_release.argocd
  ]
}


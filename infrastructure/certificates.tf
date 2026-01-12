
# Cert Manager for Let's Encrypt certificates
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.13.2"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
  # 600 Seconds timeout, takes some time to boot this one up.
  timeout    = 600
  depends_on = [azurerm_kubernetes_cluster.default]
}

# Let's Encrypt ClusterIssuer
resource "kubectl_manifest" "letsencrypt" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = local.letsencrypt_cert_cluster_issuer
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = local.letsencrypt_notifications_email
        privateKeySecretRef = {
          name = local.letsencrypt_cert_cluster_issuer
        }
        solvers = [{
          http01 = {
            ingress = {
              ingressClassName = "nginx"
            }
          }
        }]
      }
    }
  })

  depends_on = [helm_release.cert_manager]
}

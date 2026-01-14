locals {
  monitoring_namespace = "monitoring"
  grafana_domain       = "grafana.${local.cluster_domain}"
}

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = "6.49.0"
  namespace        = local.monitoring_namespace
  create_namespace = true

  values = [
    yamlencode({
      # Explicitly set the deployment mode to SingleBinary
      deploymentMode = "SingleBinary"

      # Configure Loki to use filesystem storage
      loki = {
        storage = {
          type = "filesystem"
        }

        commonConfig = {
          replication_factor = 1
        }

        limits_config = {
          volume_enabled = true
        }
        auth_enabled = false # Disable multi-tenancy


        # Add the schema configuration for filesystem storage
        schemaConfig = {
          configs = [{
            from         = "2024-04-01"
            store        = "tsdb"
            object_store = "filesystem" # Changed from "s3" to "filesystem"
            schema       = "v13"
            index = {
              prefix = "loki_index_"
              period = "24h"
            }
          }]
        }
      }

      # Ensure MinIO is disabled
      minio = {
        enabled = false
      }

      # Explicitly set replica counts to ensure only the single binary pod is created
      singleBinary = {
        replicas = 1
      }
      chunksCache = {
        enabled = false
      }
      resultsCache = {
        enabled = false
      }
      backend        = { replicas = 0 }
      read           = { replicas = 0 }
      write          = { replicas = 0 }
      ingester       = { replicas = 0 }
      querier        = { replicas = 0 }
      queryFrontend  = { replicas = 0 }
      queryScheduler = { replicas = 0 }
      distributor    = { replicas = 0 }
      compactor      = { replicas = 0 }
      indexGateway   = { replicas = 0 }
      bloomCompactor = { replicas = 0 }
      bloomGateway   = { replicas = 0 }
    })
  ]
}

resource "helm_release" "promtail" {
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = "6.15.5" # Use a recent version of the Promtail chart
  namespace        = local.monitoring_namespace
  create_namespace = true

  values = [
    yamlencode({
      config = {
        clients = [
          {
            url = "http://loki.${local.monitoring_namespace}.svc.cluster.local:3100/loki/api/v1/push"
          }
        ]
      }
    })
  ]

  depends_on = [helm_release.loki]
}

resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = "25.20.0"
  namespace        = local.monitoring_namespace
  create_namespace = true

  values = [
    yamlencode({
      server = {
        ingress = {
          enabled = false # Not exposing prometheus directly
        }
      }
    })
  ]

  depends_on = [azurerm_kubernetes_cluster.default]
}


resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = "10.5.6"
  namespace        = local.monitoring_namespace
  create_namespace = true

  values = [
    yamlencode({
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [{
            name      = "Loki"
            type      = "loki"
            url       = "http://loki.${local.monitoring_namespace}.svc.cluster.local:3100"
            access    = "proxy"
            isDefault = true
            },
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server.${local.monitoring_namespace}.svc.cluster.local"
              access    = "proxy"
              isDefault = false
          }]
        }
      }

      ingress = {
        enabled          = true
        ingressClassName = local.default_ingress_classname
        hosts            = [local.grafana_domain]
        path             = "/"
        tls = [{
          secretName = "grafana-tls"
          hosts      = [local.grafana_domain]
        }]
        annotations = {
          "cert-manager.io/cluster-issuer" = local.letsencrypt_cert_cluster_issuer
        }
      }
    })
  ]
}

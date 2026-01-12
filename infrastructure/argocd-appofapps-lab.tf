# ArgoCD App-of-Apps for lab environment
resource "kubectl_manifest" "argocd_app_of_apps_lab" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "lab-apps-generator"
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = {
      goTemplate = true
      generators = [
        {
          git = {
            repoURL  = local.github_repo_url
            revision = "HEAD"
            directories = [
              {
                # Scans excercises/<namespace>/<app-name>. Excludes directories starting with _ 
                path = "excercises/*/*"
              },
              {
                path    = "*/_*"
                exclude = true
              }
            ]
        } }
      ]
      template = {
        metadata = {
          name = "{{.path.basename}}"
        }
        spec = {
          project = "default"
          source = {
            repoURL        = local.github_repo_url
            targetRevision = "HEAD"
            path           = "{{.path.path}}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{index .path.segments 1}}"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = ["CreateNamespace=true"]
          }
        }
    } }
  })

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.argocd_repo_infrastructure
  ]
}

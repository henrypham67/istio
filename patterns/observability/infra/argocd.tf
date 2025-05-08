resource "argocd_application" "app_of_apps" {
  metadata {
    name      = "observability"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = var.git_argocd_repo_url
      path            = "patterns/observability/argo/apps/dev"
      target_revision = "HEAD"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "observability"
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
    }
  }
}
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# -------------------------
# DEV Namespace
# -------------------------
resource "kubernetes_namespace_v1" "fintech_dev" {
  metadata {
    name = "fintech-dev"

    labels = {
      environment = "dev"
      project     = "fintech"
    }
  }
}

# -------------------------
# PROD Namespace
# -------------------------
resource "kubernetes_namespace_v1" "fintech_prod" {
  metadata {
    name = "fintech-prod"

    labels = {
      environment = "prod"
      project     = "fintech"
    }
  }
}

# -------------------------
# Observability Namespace
# -------------------------
resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = "observability"

    labels = {
      purpose = "monitoring"
    }
  }
}

# -------------------------
# Resource Quota (DEV)
# -------------------------
resource "kubernetes_resource_quota_v1" "dev_quota" {
  metadata {
    name      = "dev-quota"
    namespace = kubernetes_namespace_v1.fintech_dev.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "2"
      "requests.memory" = "2Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "4Gi"
    }
  }
}
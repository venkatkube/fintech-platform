provider "kubernetes" {
  config_path = "~/.kube/config"
}

# -------------------------
# DEV Namespace
# -------------------------
resource "kubernetes_namespace" "fintech_dev" {
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
resource "kubernetes_namespace" "fintech_prod" {
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
resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"

    labels = {
      purpose = "monitoring"
    }
  }
}

resource "kubernetes_resource_quota" "dev_quota" {
  metadata {
    name      = "dev-quota"
    namespace = kubernetes_namespace.fintech_dev.metadata[0].name
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
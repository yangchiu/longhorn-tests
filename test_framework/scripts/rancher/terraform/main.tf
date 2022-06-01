terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 1.24"
    }
  }
}

provider "rancher2" {
  api_url   = var.api_url
  insecure  = true
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "rancher2_catalog_v2" "longhorn_repo" {
  cluster_id = "local"
  name = "longhorn-repo"
  git_repo = "https://github.com/innobead/charts-1.git"
  git_branch = "longhorn-1.3.0-2.6"
}

resource "rancher2_app_v2" "longhorn_app" {
  cluster_id = "local"
  name = "longhorn-app"
  namespace = "longhorn-system"
  repo_name = "longhorn-repo"
  chart_name = "longhorn"
  chart_version = "100.2.1+up1.3.0-rc1"
  #values = file("values.yaml")
  wait = true
}
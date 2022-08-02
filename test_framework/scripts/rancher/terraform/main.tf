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

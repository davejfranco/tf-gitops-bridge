terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.14.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.31.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-local"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "kind-local"
  }
}


locals {
  name                   = "kind-local"
  aws_region             = "us-west-2"
  vpc_id                 = "vpc-12345678"
  environment            = "dev"
  cluster_version        = "1.29.2"
  gitops_addons_url      = "https://github.com/gitops-bridge-dev/gitops-bridge-argocd-control-plane-template"
  gitops_addons_basepath = ""
  gitops_addons_path     = "bootstrap/control-plane/addons"
  gitops_addons_revision = "HEAD"

  oss_addons = {
    enable_argo_workflows = true
  }

  addons = merge(local.oss_addons, { kubernetes_version = local.cluster_version })

  addons_metadata = merge(
    {
      cluster_name = local.name
      environment  = local.environment
      region       = local.aws_region
      vpc_id       = local.vpc_id
    },
    {
      addons_repo_url      = local.gitops_addons_url
      addons_repo_basepath = local.gitops_addons_basepath
      addons_repo_path     = local.gitops_addons_path
      addons_repo_revision = local.gitops_addons_revision
    }
  )

  argocd_apps = {
    addons = file("${path.module}/bootstrap/addons.yaml")
    apps   = file("${path.module}/bootstrap/apps.yaml")
  }

}

################################################################################
# GitOps Bridge: Bootstrap
################################################################################
module "gitops_bridge_bootstrap" {
  source  = "gitops-bridge-dev/gitops-bridge/helm"
  version = "0.1.0"

  cluster = {
    cluster_name = local.name
    environment  = local.environment
    metadata     = local.addons_metadata
    addons       = local.addons
  }
  apps = local.argocd_apps
}


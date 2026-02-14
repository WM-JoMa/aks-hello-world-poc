data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "terraform_remote_state" "acr" {
  backend = "azurerm"

  config = {
    resource_group_name  = "aks-hello-world-poc"
    storage_account_name = "stakspoctfstate"
    container_name       = "terraformstatefiles"
    key                  = "acr_poc.tfstate"
  }
}

locals {
  acr_login_server = "${var.acr_name}.azurecr.io"
  image            = "${local.acr_login_server}/${var.image_name}:${var.image_tag}"

  k8s_namespace       = var.app_name
  k8s_app_label       = var.app_name
  k8s_deployment_name = "${var.app_name}-app"
  k8s_service_name    = "${var.app_name}-service"
}


resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix          = var.aks_dns_prefix

  default_node_pool {
    name            = "default"
    node_count      = var.default_node_pool_node_count
    vm_size         = var.default_node_pool_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  tags                = var.tags
}

resource "azurerm_role_assignment" "this" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = data.azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

resource "kubernetes_namespace_v1" "hello_world_ns" {
  depends_on = [azurerm_role_assignment.this]
  metadata {
    name = local.k8s_namespace
  }
}

resource "kubernetes_deployment_v1" "hello_world_app" {
  depends_on = [azurerm_role_assignment.this]
  metadata {
    name      = local.k8s_deployment_name
    namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
    labels = {
      app = local.k8s_app_label
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.k8s_app_label
      }
    }

    template {
      metadata {
        labels = {
          app = local.k8s_app_label
        }
      }

      spec {
        container {
          name  = "${local.k8s_namespace}-container"
          image = local.image
          image_pull_policy = "Always"

          port {
            container_port = 8080
          }

          # Optional but recommended for stable rollouts
          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "hello_world_service" {
  depends_on = [azurerm_role_assignment.this]
  metadata {
    name      = local.k8s_service_name
    namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
  }

  spec {
    selector = {
      app = local.k8s_app_label
    }

    type = "LoadBalancer"

    port {
      port        = 80
      target_port = 8080
    }
  }
}

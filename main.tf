data "azurerm_resource_group" "rg" {
  name     = "aks-hello-world-poc"
}

locals {
  tags = {
    "Owner 1"         : "agreenwald@westmonroe.com"
    "Owner 2"         : "None"
    "Client Code"     : "Jepp-POC"
  }
  image = "wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:${var.image_tag}"
}

resource "azurerm_container_registry" "hello_world" {
  name                = "wmpagreenwaldhelloworldacr"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-hello-world-cluster"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix          = "akshelloworld"

  default_node_pool {
    name            = "default"
    node_count      = 1
    vm_size         = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags                = local.tags
}

resource "azurerm_role_assignment" "this" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.hello_world.id
  skip_service_principal_aad_check = true
}

resource "kubernetes_namespace_v1" "hello_world_ns" {
  depends_on = [azurerm_role_assignment.this]
  metadata {
    name = "hello-world"
  }
}

resource "kubernetes_deployment_v1" "hello_world_app" {
  metadata {
    name      = "hello-world-app"
    namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
    labels = {
      app = "hello-world"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "hello-world"
      }
    }

    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }

      spec {
        container {
          name  = "hello-world-container"
          image = "wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1"

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
  metadata {
    name      = "hello-world-service"
    namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
  }

  spec {
    selector = {
      app = "hello-world"
    }

    type = "LoadBalancer"

    port {
      port        = 80
      target_port = 8080
    }
  }
}

data "azurerm_resource_group" "rg" {
  name     = "aks-hello-world-poc"
}

locals {
  tags = {
    "Owner 1"         : "agreenwald@westmonroe.com"
    "Owner 2"         : "None"
    "Client Code"     : "Jepp-POC"
  }
}

resource "azurerm_container_registry" "hello_world" {
  name                = "wmpagreenwaldhelloworldacr"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"
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

# resource "null_resource" "build_and_push_docker_image" {
#   provisioner "local-exec" {
#     command = <<EOT
# docker build -t helloworld-java:v1 .
# az acr create --name wmpagreenwaldhelloworldacr --resource-group \${data.azurerm_resource_group.rg.name} --sku Basic
# az acr login --name wmpagreenwaldhelloworldacr
# docker tag helloworld-java:v1 wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1
# docker push wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1
# EOT
#   }
# }

resource "null_resource" "build_and_push_docker_image" {
  depends_on = [ azurerm_role_assignment.this ]
  provisioner "local-exec" {
    command = <<EOT
az acr login --name wmpagreenwaldhelloworldacr
docker build -t wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1 .
docker push wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1
EOT
  }
}

resource "kubernetes_namespace_v1" "hello_world_ns" {
  depends_on = [ null_resource.build_and_push_docker_image ]
  metadata {
    name = "hello-world"
  }
}

# resource "kubernetes_deployment_v1" "hello_world_app" {
#   depends_on = [ null_resource.build_and_push_docker_image ]
#   metadata {
#     name      = "hello-world-app"
#     namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
#   }

#   spec {
#     selector {
#       match_labels = {
#         app = "hello-world"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "hello-world"
#         }
#       }

#       spec {
#         container {
#           name  = "hello-world-container"
#           image = "wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1"

#           port {
#             container_port = 8080
#           }
#         }
#       }
#     }
#   }
# }

# resource "kubernetes_service_v1" "hello_world_service" {
#   depends_on = [ null_resource.build_and_push_docker_image ]
#   metadata {
#     name      = "hello-world-service"
#     namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
#   }

#   spec {
#     selector = {
#       app = "hello-world"
#     }

#     type = "LoadBalancer"

#     port {
#       port        = 80
#       target_port = 8080
#     }
#   }
# }

resource "kubernetes_job_v1" "hello_world_job" {
  depends_on = [null_resource.build_and_push_docker_image]

  metadata {
    name      = "hello-world-job"
    namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
  }

  spec {
    # Optional: retry behavior
    backoff_limit = 0

    template {
      metadata {
        labels = {
          app = "hello-world"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "hello-world-container"
          image = "wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1"
        }
      }
    }

    # Optional: auto-cleanup finished jobs (K8s >= 1.21, AKS supports this)
    ttl_seconds_after_finished = 600
  }
}

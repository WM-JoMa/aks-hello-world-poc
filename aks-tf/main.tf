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

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-hello-world-cluster"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix          = "akshelloworld"

  default_node_pool {
    name            = "default"
    node_count      = 2
    vm_size         = "Standard_DS2_v2"
    os_disk_size_gb = 30
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  tags                = local.tags
}

resource "null_resource" "build_and_push_docker_image" {
  provisioner "local-exec" {
    command = <<EOT
docker build -t helloworld-java:v1 .
az acr create --name wmpagreenwaldhelloworldacr --resource-group \${data.azurerm_resource_group.rg.name} --sku Basic
az acr login --name wmpagreenwaldhelloworldacr
docker tag helloworld-java:v1 wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1
docker push wmpagreenwaldhelloworldacr.azurecr.io/helloworld-java:v1
EOT
  }
}

resource "kubernetes_namespace_v1" "hello_world_ns" {
  metadata {
    name = "hello-world"
  }
}

resource "kubernetes_deployment_v1" "hello_world_app" {
  metadata {
    name      = "hello-world-app"
    namespace = kubernetes_namespace_v1.hello_world_ns.metadata[0].name
  }

  spec {
    replicas = 2

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

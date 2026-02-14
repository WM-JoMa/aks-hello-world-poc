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

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}
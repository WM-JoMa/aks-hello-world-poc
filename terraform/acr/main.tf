data "azurerm_resource_group" "rg" {
  name     = "aks-hello-world-poc"
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
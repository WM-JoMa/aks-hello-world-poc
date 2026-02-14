data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_container_registry" "hello_world" {
  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = var.acr_sku

  tags = var.tags

  lifecycle {
    prevent_destroy = var.prevent_destroy
  }
}

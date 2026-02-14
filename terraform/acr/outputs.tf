output "container_registry_id" {
  description = "The resource ID of the Azure Container Registry."
  value       = azurerm_container_registry.hello_world.id
}
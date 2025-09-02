# outputs.tf

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "container_app_environment_name" {
  description = "Name of the Container Apps Environment"
  value       = azurerm_container_app_environment.main.name
}

output "container_app_name" {
  description = "Name of the Container App"
  value       = azurerm_container_app.api.name
}

output "container_app_url" {
  description = "URL of the deployed Container App"
  value       = "https://${azurerm_container_app.api.latest_revision_fqdn}"
}
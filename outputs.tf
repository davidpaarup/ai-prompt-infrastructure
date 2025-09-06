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

output "github_actions_client_id" {
  description = "Client ID for GitHub Actions service principal"
  value       = azuread_application.github_actions.client_id
}

output "github_actions_client_secret" {
  description = "Client secret for GitHub Actions service principal"
  value       = azuread_service_principal_password.github_actions.value
  sensitive   = true
}

output "tenant_id" {
  description = "Azure tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Azure subscription ID"
  value       = data.azurerm_client_config.current.subscription_id
}
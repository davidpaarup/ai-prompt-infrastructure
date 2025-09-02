# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  required_version = ">= 1.0"
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# Create Log Analytics Workspace for Container Apps
#resource "azurerm_log_analytics_workspace" "main" {
#  name                = "${var.project_name}-law"
#  location            = azurerm_resource_group.main.location
#  resource_group_name = azurerm_resource_group.main.name
#  sku                 = "PerGB2018"
#  retention_in_days   = 30
#}

# Create Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = true
}

# Create Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  #log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# Create Container App
resource "azurerm_container_app" "api" {
  name                         = "${var.project_name}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "api"
      image  = var.initial_container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = var.aspnet_environment
      }

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://0.0.0.0:8080"
      }
    }

    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 8080

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# Create Key Vault for storing secrets
resource "azurerm_key_vault" "main" {
  name                       = "${var.project_name}-kv"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]
  }
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Data sources for SQL credentials from Key Vault
data "azurerm_key_vault_secret" "sql_admin_username" {
  name         = "sql-admin-username"
  key_vault_id = azurerm_key_vault.main.id
}

data "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  key_vault_id = azurerm_key_vault.main.id
}

# Create SQL Server
resource "azurerm_mssql_server" "ia_prompt" {
  name                         = "ia-prompt"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = data.azurerm_key_vault_secret.sql_admin_username.value
  administrator_login_password = data.azurerm_key_vault_secret.sql_admin_password.value
}

# Create SQL Database
resource "azurerm_mssql_database" "ia_prompt" {
  name           = "ia-prompt"
  server_id      = azurerm_mssql_server.ia_prompt.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "Basic"
}

# Create SQL Server Firewall Rule - Allow all IPs
resource "azurerm_mssql_firewall_rule" "allow_all_ips" {
  name             = "AllowAllIPs"
  server_id        = azurerm_mssql_server.ia_prompt.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Store Application Insights connection string in Key Vault
#resource "azurerm_key_vault_secret" "app_insights_connection_string" {
  #name         = "ApplicationInsights--ConnectionString"
  #value        = azurerm_application_insights.main.connection_string
  #key_vault_id = azurerm_key_vault.main.id

 # depends_on = [azurerm_key_vault.main]
#}

# Store ACR credentials in Key Vault
#resource "azurerm_key_vault_secret" "acr_username" {
  #name         = "ACR--Username"
  #value        = azurerm_container_registry.main.admin_username
  #key_vault_id = azurerm_key_vault.main.id

#  depends_on = [azurerm_key_vault.main]
#}

#resource "azurerm_key_vault_secret" "acr_password" {
#  name         = "ACR--Password"
#  value        = azurerm_container_registry.main.admin_password
#  key_vault_id = azurerm_key_vault.main.id

 # depends_on = [azurerm_key_vault.main]
#}

# Store SQL Server credentials in Key Vault
resource "azurerm_key_vault_secret" "sql_admin_username" {
  name         = "sql-admin-username"
  value        = var.sql_admin_username
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault.main]
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault.main]
}
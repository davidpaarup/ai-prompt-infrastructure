terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "main" {
  name                = var.container_registry_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = true
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
}

resource "azurerm_container_app" "api" {
  name                         = "${var.project_name}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    container {
      name   = "api"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = var.container_cpu
      memory = var.container_memory

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ASPNETCORE_URLS"
        value = "http://0.0.0.0:8080"
      }

      env {
        name  = "ClientId"
        value = azuread_application.ai_prompt.client_id
      }

      env {
        name  = "ClientSecret"
        value = azuread_application_password.ai_prompt.value
      }

      env {
        name  = "OpenAIKey"
        value = var.openai_key
      }

      env {
        name = "ConnectionString"
        value = "Server=${azurerm_mssql_server.ai_prompt.fully_qualified_domain_name};Database=${azurerm_mssql_database.ai_prompt.name};User Id=${var.sql_admin_username};Password=${var.sql_admin_password};Encrypt=true;TrustServerCertificate=false;"
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
      "Restore",
      "Purge"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azuread_service_principal.github_actions.object_id

    secret_permissions = [
      "Get",
      "List"
    ]
  }
}

data "azurerm_client_config" "current" {}

resource "azuread_application" "github_actions" {
  display_name = "github-actions-sp"
}

resource "azuread_application" "ai_prompt" {
  display_name                   = "AI Prompt"
  sign_in_audience               = "AzureADandPersonalMicrosoftAccount"

  api {
    requested_access_token_version = 2
  }

  web {
    redirect_uris = [
      "https://ai-prompt-bice.vercel.app/api/auth/callback/microsoft",
      "http://localhost:3000/api/auth/callback/microsoft"
    ]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "10465720-29dd-4523-a11a-6a75c743c9d9" # User.Read
      type = "Scope"
    }

    resource_access {
      id   = "df85f4d6-205c-4ac5-a5ea-6bf408dba283" # Files.Read
      type = "Scope"
    }

    resource_access {
      id   = "570282fd-fa5c-430d-a7fd-fc8dc98a9dca" # Mail.Read
      type = "Scope"
    }

    resource_access {
      id   = "e383f46e-2787-4529-855e-0e479a3ffac0" # Mail.Send
      type = "Scope"
    }

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read (additional scope)
      type = "Scope"
    }
  }
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
}

resource "azuread_service_principal_password" "github_actions" {
  service_principal_id = azuread_service_principal.github_actions.object_id
}

resource "azuread_service_principal" "ai_prompt" {
  client_id = azuread_application.ai_prompt.client_id
}

resource "azuread_application_password" "ai_prompt" {
  application_id = azuread_application.ai_prompt.id
}

resource "azurerm_key_vault_secret" "github_actions_client_secret" {
  name         = "client-secret"
  value        = azuread_service_principal_password.github_actions.value
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = var.sql_admin_password
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_mssql_server" "ai_prompt" {
  name                         = "ai-prompt"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
}

resource "azurerm_mssql_database" "ai_prompt" {
  name           = "ai-prompt"
  server_id      = azurerm_mssql_server.ai_prompt.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "Basic"
}

resource "azurerm_mssql_firewall_rule" "allow_all_ips" {
  name             = "AllowAllIPs"
  server_id        = azurerm_mssql_server.ai_prompt.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}
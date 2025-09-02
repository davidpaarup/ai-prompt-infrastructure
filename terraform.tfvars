project_name            = "ai-prompt-api"
resource_group_name     = "ai-prompt"
location                = "Norway East"
container_registry_name = "davidpaarup" 
acr_sku                 = "Basic"

container_cpu    = 0.5
container_memory = "1.0Gi"
min_replicas     = 0   
max_replicas     = 1
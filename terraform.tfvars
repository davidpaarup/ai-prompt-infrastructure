project_name            = "semantic-kernel-api"
resource_group_name     = "ai-project"
location                = "Norway East"
container_registry_name = "testregistrypaarup" 
acr_sku                 = "Basic"

container_cpu    = 0.5
container_memory = "1.0Gi"
min_replicas     = 0   
max_replicas     = 10 

aspnet_environment = "Production"
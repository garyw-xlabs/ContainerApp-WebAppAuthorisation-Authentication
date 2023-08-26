resource "azurerm_role_assignment" "containerapp" {
  scope                = lower("/subscriptions/bb87627c-ce2f-4c01-8257-2e5c1f074a28/resourceGroups/${var.resource_group_name}/providers/Microsoft.ContainerRegistry/registries/${var.registry_name}")
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.acr_reader.principal_id
}

resource "azurerm_user_assigned_identity" "acr_reader" {
  location            = var.location
  name                = "app-acr-reader"
  resource_group_name = var.resource_group_name
}

resource "azuread_application" "container_app_application" {
  display_name    = "NextJs ${var.resource_token}"
  identifier_uris = ["api://${var.resource_token}"]

  api {
    mapped_claims_enabled          = true
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access example on behalf of the signed-in user."
      admin_consent_display_name = "Access example"
      enabled                    = true
      id                         = uuid()
      type                       = "User"
      user_consent_description   = "Allow the application to access example on your behalf."
      user_consent_display_name  = "Access example"
      value                      = "user_impersonation"
    }
  }
  web {
    homepage_url  = "https://ca-${var.resource_token}.${var.containerapp_env_url}"
    redirect_uris = ["https://ca-${var.resource_token}.${var.containerapp_env_url}/.auth/login/aad/callback"]

    implicit_grant {
      id_token_issuance_enabled = true
    }

  }
}


resource "azuread_service_principal" "container_app_service_principle" {
  application_id               = azuread_application.container_app_application.application_id
  app_role_assignment_required = false
}

resource "azuread_service_principal_password" "container_app_service_principle_password" {
  service_principal_id = azuread_service_principal.container_app_service_principle.id
}

resource "azurerm_container_app" "app" {
  name = "ca-${var.resource_token}"

  container_app_environment_id = var.containerapp_env_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = merge(tomap({ "azd-service-name" = "nextapp-restricted-ad" }), tomap({ "azd-env-name" : var.environment }))
  depends_on = [azurerm_role_assignment.containerapp,
    azurerm_user_assigned_identity.acr_reader,
  azuread_service_principal_password.container_app_service_principle_password]


  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.acr_reader.id]
  }
  
  secret {
    name  = "auth-password"
    value = azuread_service_principal_password.container_app_service_principle_password.value
  }

  secret {
    name  = "registry-password"
    value = data.azurerm_container_registry.acr.admin_password
  }

  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.acr_reader.id
  }

  template {
    container {
      name   = "ca-${var.resource_token}"
      image  = var.image_name == "" ? "nginx:latest" : var.image_name
      cpu    = 0.25
      memory = "0.5Gi"
    }
    min_replicas = 1
    max_replicas = 1
  }
  ingress {

    external_enabled = true
    target_port      = 3000
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  lifecycle {
    ignore_changes = [
      secret,
      template.0.container.0.env,
      template.0.container.0.image
    ]
  }

}

resource "azapi_resource" "containerauth" {
  type      = "Microsoft.App/containerApps/authConfigs@2022-11-01-preview"
  name      = "current"
  parent_id = azurerm_container_app.app.id
  body = jsonencode({
    properties = {
      globalValidation = {
        excludedPaths               = []
        unauthenticatedClientAction = "RedirectToLoginPage"
      }
      platform = {
      enabled = true }
      httpSettings = {
        requireHttps = true
      }
      identityProviders = {
        azureActiveDirectory = {
          enabled = true

          registration = {
            clientId                = azuread_application.container_app_application.application_id
            clientSecretSettingName = "auth-password"
            openIdIssuer            = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/v2.0"
          }
          validation = {
            allowedAudiences = [
              "api://${var.resource_token}"
            ]
            defaultAuthorizationPolicy = {
              allowedPrincipals = {
                identities = [
                  "user object id"
                ]
              }
            }
          }
        }
      }
    }
  })
}

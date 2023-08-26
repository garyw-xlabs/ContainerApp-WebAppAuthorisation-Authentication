output "API_SERVICE_PRINCIPLE" {
  value = azuread_service_principal.container_app_service_principle.object_id
}

output "API_URL" {
  value = azurerm_container_app.app.latest_revision_fqdn
}

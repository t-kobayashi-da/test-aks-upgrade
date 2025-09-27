output "kube_config" {
  description = "Kube config content"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "fqdn" {
  description = "FQDN for Kubernetes API"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "agent_pool_name" {
  description = "Default agent pool name"
  value       = azurerm_kubernetes_cluster.aks.default_node_pool[0].name
}

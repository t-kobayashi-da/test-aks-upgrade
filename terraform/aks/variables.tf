variable "resource_group_name" {
  type        = string
  description = "Resource Group name"
  default     = "koba-rg-aks-upgrade-lab"
}

variable "location" {
  type        = string
  description = "Azure region"
  default     = "japaneast"
}

variable "aks_cluster_name" {
  type        = string
  description = "AKS cluster name"
  default     = "koba-aks-upgrade-lab"
}

variable "dns_prefix" {
  type        = string
  description = "DNS prefix for AKS"
  default     = "kobaaksupgrade"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for AKS"
  default     = "1.30.14"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in default node pool"
  default     = 1
}

variable "node_vm_size" {
  type        = string
  description = "VM size for nodes"
  default     = "Standard_B2s"
}

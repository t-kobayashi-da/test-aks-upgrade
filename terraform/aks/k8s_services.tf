provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

resource "kubernetes_service" "nginx_lb" {
  metadata {
    name = "nginx"
    namespace = "default"
  }

  spec {
    type = "LoadBalancer"
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "kubernetes_service" "argocd_lb" {
  metadata {
    name      = "argocd-server-lb"
    namespace = "argocd"
  }

  spec {
    type = "LoadBalancer"
    selector = {
      "app.kubernetes.io/name" = "argocd-server"
    }

    port {
      name        = "https"
      port        = 8080       # 任意の外部ポート
      target_port = 8080        # Pod 内は 443
    }
  }
}

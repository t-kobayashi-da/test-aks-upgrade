まずは **1️⃣ クラスタ構築（Terraform）** の詳細手順を出します。
ただし、**バージョン 1.30.14 → 1.32.x** のアップグレード計画に沿う構成も意識しつつ進めます。

以下は手順と Terraform のコード構成案、および注意点です。

---

## 1️⃣ クラスタ構築（Terraform）詳細手順

### 1-1. AKS Kubernetes バージョンの確認

* AKS は、サポートされている Kubernetes バージョンを常に把握しておく必要があります。
  Microsoft ドキュメントによると、AKS では最新 GA マイナーバージョンおよびその 2 つ前のマイナーバージョンがサポート対象となっています ([Microsoft Learn][1])
* あなたが使えるバージョンとして「1.30.14」が現時点で可能とのことですが、それを基準に構築しておき、後で 1.31 → 1.32 と順次アップグレードする形が妥当です。

> 補足：1.32 は LTS サポート対象マイナーバージョンと見られる（ドキュメント上、1.32 の LTS 支援が言及されている）([Microsoft Learn][2])

---

### 1-2. Terraform コード構成案

リポジトリを以下のような構成とすると見通しがよくなります：

```
test-aks-upgrade/
  ├── terraform/
  │     └── aks/
  │           ├── providers.tf
  │           ├── variables.tf
  │           ├── main.tf
  │           ├── outputs.tf
  │           └── versions.tf  (optional: Terraform / provider version pinning)
  ├── docs/        ← 学習ノートや手順メモなど
  └── README.md
```

それぞれのファイルに記述する内容の概要は以下：

| ファイル名            | 内容                                                      |
| ---------------- | ------------------------------------------------------- |
| **providers.tf** | Azure provider の設定、バージョン制約、Feature Flags など             |
| **versions.tf**  | Terraform のバージョン制約と provider バージョン制約（オプション）             |
| **variables.tf** | 入力変数定義（resource group 名、クラスタ名、リージョン、DNS prefix、バージョンなど） |
| **main.tf**      | AKS クラスタ、ノードプール、ネットワーク（VNet/Subnet）など主要リソース定義           |
| **outputs.tf**   | 外部公開 IP、クラスター接続情報、DNS 名などの出力                            |

---

### 1-3. Terraform コード例（サンプル）

以下は **簡易なサンプルコード** です。実際に使う際は変数やパラメータを調整してください。

#### providers.tf

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}
```

#### variables.tf

```hcl
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
```

#### main.tf

```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix

  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name       = "nodepool1"
    node_count = var.node_count
    vm_size    = var.node_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  # optional: enable auto-upgrade for patch channel
  # auto_upgrade_profile {
  #   upgrade_channel = "patch"
  # }
}
```

#### outputs.tf

```hcl
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
```

---

### 1-4. Terraform の初期化 → 適用

1. 初期化

   ```bash
   cd terraform/aks
   terraform init
   ```

2. 計画を確認

   ```bash
   terraform plan -var="kubernetes_version=1.30.14"
   ```

3. 適用

   ```bash
   terraform apply -var="kubernetes_version=1.30.14" -auto-approve
   ```

4. 適用後、出力を受け取る
   `terraform output` で `kube_config` や API FQDN 等を取得できます。

---

### 1-5. 動作確認（kubectl）

Terraform の出力から `kube_config` を使って `kubectl` をセット：

```bash
# kubeconfig を環境変数等に書き出す
echo "$(terraform output -raw kube_config)" > ~/.kube/test-aks-upgrade-config
export KUBECONFIG=~/.kube/test-aks-upgrade-config

# ノード確認
kubectl get nodes
```

ノードが `Ready` であることを確認してください。

---

### 1-6. リスク・注意点／要検討項目

* **バージョンの飛びすぎアップグレード禁止**
  AKS ではマイナーバージョンを飛ばしてアップグレードすることは通常サポートされていません。順次アップグレードする必要があります ([Reddit][3])
* **LTS / Premium 切り替え**
  後段で LTS（Premium ティア）へ切り替えることを考えておく（Terraform で `tier = "Premium"` や `k8s_support_plan = "AKSLongTermSupport"` を扱う必要あり）([Microsoft Learn][2])
* **パッチチャネル自動アップグレード**
  クラスタを長期保守するなら、自動パッチ適用チャネルを有効化するのが望ましい
* **ノードスケール**
  最初は最小構成でよいが、将来的な検証でスケールアップ／スケールアウトを試すと学びになる

---

この構成でまず AKS クラスタを起動してみましょう。
次に「nginx を Pod と Service（LoadBalancer）で動かす」ステップに移りますが、その前にこの Terraform 構成で問題や質問があれば先に対処できます — 進めてよろしいでしょうか？

[1]: https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?utm_source=chatgpt.com "Supported Kubernetes versions in Azure ..."
[2]: https://learn.microsoft.com/en-us/azure/aks/long-term-support?utm_source=chatgpt.com "Long-term support for Azure Kubernetes Service (AKS) ..."
[3]: https://www.reddit.com/r/AZURE/comments/16bujek/azure_aks_upgrade_path_from_1238_to_current/?utm_source=chatgpt.com "Azure AKS Upgrade - Path from 1.23.8 to Current"

Terraform はすでにインストール済み（v1.9.8）

---

## ✅ 0️⃣ 事前準備 詳細手順

### 0-1. Azure CLI のインストール & バージョン確認

Terraform から AKS を構築するには Azure CLI が必要です。

1. **インストール (Homebrew 使用)**

   ```bash
   brew update
   brew install azure-cli
   ```

   すでにインストール済みの場合はアップデート：

   ```bash
   brew upgrade azure-cli
   ```

2. **バージョン確認**

   ```bash
   az version
   ```

   * 目安：`2.65.x` 以上であればOK。

---

### 0-2. Azure へのログイン

1. ブラウザで Microsoft アカウント認証

   ```bash
   az login
   ```

   成功すると、サブスクリプション情報が JSON 形式で出力されます。

2. **サブスクリプション確認**

   ```bash
   az account list --output table
   ```

   複数ある場合は使用するものを選び、`<SUBSCRIPTION_ID>` を控えます。

3. **サブスクリプションを設定**

   ```bash
   az account set --subscription <SUBSCRIPTION_ID>
   ```

   > 以降、このサブスクリプションに対してTerraformからリソースを作成します。

---

### 0-3. Terraform の Azure 認証設定

Terraform が Azure に接続するための認証情報を用意します。
**Azure CLI 認証**を使うので、環境変数設定は不要です。
（Terraform 実行時に自動的に `az login` のセッションを利用します）

ただし将来 CI/CD で GitHub Actions を使う場合に備え、
Service Principal の作成も学習しておくと便利です。

> *Service Principal 作成は後で GitHub Actions 連携時に実施予定。今は不要*

---

### 0-4. GitHub リポジトリ準備

ラーニングパス全体のコードと記録を**1つのリポジトリ**で管理します。

1. **GitHub で新規リポジトリ作成**

   * リポジトリ名例: `aks-upgrade-lab`
   * Public/Private は任意
   * `.gitignore` は `Terraform` を選択しておくと便利

2. **ローカルへクローン**

   ```bash
   cd ~/work   # 任意の作業ディレクトリ
   git clone git@github.com:<USERNAME>/aks-upgrade-lab.git
   cd aks-upgrade-lab
   ```

3. **初期コミット (README追加)**

   ```bash
   echo "# AKS Upgrade Lab" > README.md
   git add README.md
   git commit -m "initial commit"
   git push origin main
   ```

---

### 0-5. Terraform プロジェクト構成の作成

後続作業で AKS を Terraform で構築するためのディレクトリを先に用意します。

```bash
mkdir -p terraform/aks
cd terraform/aks
touch main.tf variables.tf outputs.tf providers.tf
```

* `main.tf`：AKS リソース定義
* `variables.tf`：変数管理
* `outputs.tf`：出力値
* `providers.tf`：Azure Provider設定

---

### 0-6. ネーミングルール・リージョン設計

リソース名とリージョンをここで決定しておきます。

| 項目         | 候補例                  |
| ---------- | -------------------- |
| リソースグループ   | `rg-aks-upgrade-lab` |
| クラスタ名      | `aks-upgrade-lab`    |
| ロケーション     | `japaneast` (推奨)     |
| DNS Prefix | `aksupgrade`         |

> このネーミングは今後 Terraform の `variables.tf` に反映します。

---

### 0-7. GitHub への初回プッシュ

Terraform プロジェクト構成をコミットしておきます。

```bash
git add terraform
git commit -m "add terraform project structure"
git push origin main
```

---

## ✅ 完了チェックリスト

* [ ] `az version` で Azure CLI が利用できる
* [ ] `az login` 済みで、サブスクリプションがセット済み
* [ ] GitHub リポジトリ作成 & ローカル同期済み
* [ ] `terraform/aks` に基本ファイルが作成済み

---

# test-aks-upgrade
AKSクラスタのLTSアップグレード検証

以下は、**AKSクラスタのバージョンアップ練習**に向けたラーニングパスの項目リストです。
この流れに沿って進めれば、「Terraformでのクラスタ構築」→「LTS(Premium)への変更」→「バージョンアップ」→「Standardへ戻す」までを段階的にハンズオンできます。
今は**詳細手順は書かず、学習と作業の流れだけ**を整理しています。

---

## 🌱 ラーニングパス：AKS バージョンアップ練習

### 0️⃣ 事前準備

* [ ] Azure環境の確認
  * Azure CLI / Terraform CLI のインストール
  * Azure サブスクリプションの確認（権限: Contributor 以上）
  * `az login` など基本操作の確認
* [ ] 開発環境
  * macOS 上で Terraform を実行する環境を整備
  * Terraform バージョン固定 (例: 1.8.x など)
* [ ] リソース設計
  * リージョン選定（例: japaneast）
  * ネーミングルール（リソースグループ名、クラスタ名など）

### 1️⃣ クラスタ構築（Terraform）

* [ ] Terraform のプロジェクト構成
  * `main.tf`, `variables.tf`, `outputs.tf` の基本構成
  * AKS, Node Pool, VNet, Subnet の最小構成
* [ ] **Standard** SKU でクラスタを作成
  * Kubernetes バージョンは「サポートされている中で最も古い」バージョンを指定
  * システムノードプールは最小構成（例: 1〜2ノード、Standard_B4msなど）

### 2️⃣ ワークロード準備（nginx + L4ロードバランサ）

* [ ] nginx Deployment と Service 作成
  * Pod 2つ以上 (replicas=2)
  * `Service type: LoadBalancer` で L4(HTTP 80) リクエストを外部公開
* [ ] 動作確認
  * パブリックIPを取得し、`curl`/ブラウザでアクセス

### 3️⃣ LTS(Premium) への変更

* [ ] AKS SKU を **Standard → Premium(LTS)** に変更
  * Terraform or Azure CLI のどちらか
  * 変更後の動作確認（nginx にアクセス可能か）

### 4️⃣ クラスタバージョンアップ

* [ ] **マイナーバージョンを2段階**アップグレード
  * 例: `1.28.x → 1.30.x`
  * Terraform でバージョン指定変更
  * ノードプールも自動アップグレードされるか確認
* [ ] バージョンアップ中の挙動観察
  * `kubectl get nodes` でノードのローリングアップデート確認
  * nginx への HTTP リクエストが途切れないかテスト

### 5️⃣ Standard への戻し

* [ ] LTS(Premium) → Standard SKU へ戻す
  * Terraform で SKU を再変更
  * nginx アクセスの再確認

### 6️⃣ 後片付け

* [ ] Terraform Destroy でリソース削除
* [ ] 検証結果のまとめ
  * バージョンアップのダウンタイム有無
  * SKU変更に伴う影響

## 💡 補足学習ポイント

* Terraform での AKS バージョン指定の仕方 (`kubernetes_version` 属性)
* `az aks get-upgrades` で利用可能なバージョンの確認方法
* SKU 変更時の課金モデル差異 (Standard vs Premium)
* バージョンアップ中の Pod のローリングアップデート動作

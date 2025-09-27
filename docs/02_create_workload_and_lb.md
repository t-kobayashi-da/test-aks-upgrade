# 2️⃣ ワークロード準備（nginx + LoadBalancer + Argo CD）

## 前提条件

* AKS クラスタは Terraform で作成済み
* Helm コマンド・Argo CD CLI は使用しない
* Argo CD は未デプロイ → kubectl でマニフェストを適用してデプロイ
* nginx の Helm Chart は未作成 → GitHub に作成
* nginx のデプロイは Argo CD が Helm Chart を参照して行う
* LoadBalancer は Terraform で作成、EXTERNAL-IP で HTTP アクセス確認
* Argo CD / nginx は AKS 上にデプロイ

---

## 手順

### 1. Argo CD を AKS にデプロイ

1. **Argo CD 用 namespace 作成**

```bash
kubectl create namespace argocd
```

2. **公式マニフェストを適用**

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

3. **Web UI アクセス用ポートフォワード**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

* ブラウザで `https://localhost:8080` にアクセス
* 初期管理者パスワード取得：

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

これはエラーになる
```
% kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
E0927 13:31:20.432076   56766 memcache.go:265] couldn't get current server API group list: Get "https://127.0.0.1:6443/api?timeout=32s": dial tcp 127.0.0.1:6443: connect: connection refused
E0927 13:31:20.432295   56766 memcache.go:265] couldn't get current server API group list: Get "https://127.0.0.1:6443/api?timeout=32s": dial tcp 127.0.0.1:6443: connect: connection refused
```

このエラーは **kubectl が AKS クラスタに接続できていない** ことが原因で`127.0.0.1:6443` に接続しようとして拒否される
これはローカルの kubeconfig が正しく AKS を指していない、またはコンテキストが切り替わっていない状態。

#### 1. AKS クラスタの資格情報を取得

Terraform で作った AKS なら `az aks get-credentials` を使って kubeconfig を設定

```bash
az aks get-credentials \
    --resource-group koba-rg-aks-upgrade-lab \
    --name koba-aks-upgrade-lab \
    --overwrite-existing
```

* `--overwrite-existing` は既存の kubeconfig に上書きする場合
* 成功すると `kubectl config get-contexts` で AKS が表示されます

#### 2. kubectl コンテキスト確認

```bash
kubectl config current-context
```

* AKS のコンテキスト名になっていることを確認
* 必要に応じて切り替え：

```bash
kubectl config use-context koba-aks-upgrade-lab
```

#### 3. 接続確認

```bash
kubectl get nodes
```

* AKS ノードが一覧表示されれば OK

#### 4. 再度パスワード取得

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

* これで Argo CD 初期パスワードが取得可能。末尾の%は不要だったので注意

https://localhost:8080
ID: admin

---

💡 補足

* このエラーは AKS に限らず、kubectl がクラスタ API サーバに接続できない場合に共通で出ます
* `127.0.0.1:6443` に接続しようとしているのは、ローカルの kubeconfig に AKS 情報がない、またはコンテキストが間違っているため

---



### 2. GitHub に nginx Helm Chart を作成

1. **Chart ディレクトリ作成**

```bash
cd test-aks-upgrade
mkdir -p charts/nginx/templates
```

2. **Chart.yaml**

```yaml
apiVersion: v2
name: nginx
description: "NGINX web server"
type: application
version: 0.1.0
appVersion: "1.23.0"
```

3. **values.yaml**

```yaml
replicaCount: 2
image:
  repository: nginx
  tag: stable
service:
  type: ClusterIP  # ここは Terraform で LB 作るため一旦 ClusterIP
  port: 80
```

4. **templates/deployment.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "nginx.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "nginx.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "nginx.name" . }}
    spec:
      containers:
      - name: nginx
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        ports:
        - containerPort: 80
```

5. **templates/service.yaml**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "nginx.fullname" . }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ include "nginx.name" . }}
  ports:
    - protocol: TCP
      port: {{ .Values.service.port }}
      targetPort: 80
```

6. **GitHub に push**

```bash
git add charts/nginx
git commit -m "add nginx Helm Chart"
git push origin main
```

---

### 3. Argo CD Web UI で nginx アプリ作成

1. Web UI にログイン
2. **New App** をクリック
3. 設定：

   * Application Name: `nginx`
   * Project: `default`
   * Repository URL: `https://github.com/<USERNAME>/test-aks-upgrade.git`
   * Path: `charts/nginx`
   * Cluster URL: `https://kubernetes.default.svc`
   * Namespace: `default`
   * Sync Policy: **Automatic**
4. アプリケーション作成 → 自動で Pod / Service がデプロイされる

⚠️ アプリケーション作成でエラーになった

```
Unable to create application: application spec for nginx is invalid: InvalidSpecError: Unable to generate manifests in charts/nginx: rpc error: code = Unknown desc = failed to execute helm template command: failed to get command args to log: helm template . --name-template nginx --namespace default --kube-version 1.30 <api versions removed> --include-crds failed exit status 1: Error: template: nginx/templates/service.yaml:4:11: executing "nginx/templates/service.yaml" at <include "nginx.fullname" .>: error calling include: template: no template "nginx.fullname" associated with template "gotpl" Use --debug flag to render out invalid YAML
```

このエラーは Helm Chart 内のテンプレートで定義されている _helpers.tpl が存在しない ために発生している

原因
- Argo CD は GitHub 上の Helm Chart をレンダリングしてマニフェストを作成する際、内部で helm template を実行
- nginx Chart の deployment.yaml と service.yaml では、{{ include "nginx.fullname" . }} が使われてる
- しかし charts/nginx/templates/_helpers.tpl が作られておらず、nginx.fullname というテンプレートが定義されていないため Error: template: no template "nginx.fullname" が出ている

charts/nginx/templates/_helpers.tpl に以下を追加
```yaml
{{- define "nginx.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "nginx.fullname" -}}
{{ .Release.Name }}-{{ .Chart.Name }}
{{- end -}}
```

---

### 4. Terraform で LoadBalancer 作成

1. **nginx Service 用に Terraform を修正**

```hcl
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
```

2. **Terraform 適用**

```bash
terraform apply -auto-approve
```

3. **EXTERNAL-IP 取得**

```bash
kubectl get svc nginx -n default
```

---

### 5. HTTP アクセス確認

```bash
curl http://<EXTERNAL-IP>
```

* nginx デフォルトページが返れば成功

---

### 6. 完了チェックリスト

* [ ] Argo CD が AKS にデプロイ済み
* [ ] nginx Helm Chart が GitHub に push されている
* [ ] Argo CD Web UI で nginx アプリが同期済み
* [ ] nginx Pod が 2 つ起動
* [ ] LoadBalancer が作成され EXTERNAL-IP が割り当てられている
* [ ] EXTERNAL-IP 経由で HTTP 80 アクセス確認

---

💡 **ポイント**

* Helm コマンド不要、Argo CD CLI 不要
* Argo CD は kubectl マニフェスト適用で AKS にデプロイ
* nginx は GitHub の Helm Chart を参照して Argo CD がデプロイ
* LoadBalancer は Terraform で作成、EXTERNAL-IP でアクセス確認

---

この手順で、**CLI に依存せず Web UI + Terraform + kubectl だけでハンズオン可能**です。

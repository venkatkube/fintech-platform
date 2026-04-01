#!/bin/bash

set -euo pipefail

echo "🚀 Bootstrapping Fintech Platform (Production-style)"

############################################
# CONFIG
############################################
CLUSTER_NAME="fintech"
NAMESPACE="fintech-dev"
REPO_URL="https://github.com/venkatkube/fintech-platform"

############################################
# 1. CREATE KIND CLUSTER (IDEMPOTENT)
############################################
if kind get clusters | grep -q "$CLUSTER_NAME"; then
  echo "✔ Cluster exists, skipping creation"
else
  cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
EOF

  echo "🧱 Creating cluster..."
  kind create cluster --config kind-config.yaml
fi

############################################
# 2. INGRESS CONTROLLER
############################################
if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  echo "🌐 Installing ingress..."
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
fi

kubectl wait --namespace ingress-nginx \
--for=condition=ready pod \
--selector=app.kubernetes.io/component=controller \
--timeout=180s

############################################
# 3. ARGOCD INSTALL
############################################
if ! kubectl get ns argocd >/dev/null 2>&1; then
  echo "⚙️ Installing ArgoCD..."
  kubectl create namespace argocd
  kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

kubectl wait --for=condition=available deployment argocd-server -n argocd --timeout=180s

############################################
# 4. NAMESPACE
############################################
kubectl create namespace $NAMESPACE 2>/dev/null || true

############################################
# 5. APPLY INFRA (Mongo + RabbitMQ)
############################################
echo "📦 Applying infra..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:4.4
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: data
          mountPath: /data/db
      volumes:
      - name: data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: $NAMESPACE
spec:
  selector:
    app: mongodb
  ports:
  - port: 27017
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
      - name: rabbitmq
        image: rabbitmq:3-management
        ports:
        - containerPort: 5672
        - containerPort: 15672
---
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: $NAMESPACE
spec:
  selector:
    app: rabbitmq
  ports:
  - port: 5672
  - port: 15672
EOF

############################################
# 6. ARGOCD APPLICATION (DECLARATIVE)
############################################
echo "🚀 Creating ArgoCD App (GitOps)..."

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fintech
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: HEAD
    path: k8s/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

############################################
# 7. BUILD IMAGE (IDEMPOTENT)
############################################
if [ -d "txn-service" ]; then
  echo "🐳 Building image..."
  cd txn-service
  docker build -t txn-service:latest .
  kind load docker-image txn-service:latest --name $CLUSTER_NAME
  cd ..
fi

############################################
# 8. INGRESS
############################################
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fintech-ingress
  namespace: $NAMESPACE
spec:
  ingressClassName: nginx
  rules:
  - host: fintech.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: txn-service
            port:
              number: 80
EOF

############################################
# 9. HOST ENTRY (SAFE)
############################################
if ! grep -q "fintech.local" /etc/hosts; then
  echo "127.0.0.1 fintech.local" | sudo tee -a /etc/hosts
fi

############################################
# 10. MONITORING
############################################
if ! kubectl get ns monitoring >/dev/null 2>&1; then
  echo "📊 Installing monitoring..."
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update

  helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace
fi

############################################
# DONE
############################################
echo ""
echo "🎉 PLATFORM READY"
echo ""
echo "👉 App: http://fintech.local/health"
echo "👉 Grafana: kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80"
echo "👉 ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""

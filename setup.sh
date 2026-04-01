#!/bin/bash

set -e

echo "🚀 Starting Fintech Platform Setup..."

############################################
# 1. Create Kind Cluster
############################################
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: fintech
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
  - containerPort: 443
    hostPort: 443
EOF

echo "🧱 Creating kind cluster..."
kind delete cluster --name fintech || true
kind create cluster --config kind-config.yaml

############################################
# 2. Install Ingress Controller
############################################
echo "🌐 Installing ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
--for=condition=ready pod \
--selector=app.kubernetes.io/component=controller \
--timeout=180s

############################################
# 3. Install ArgoCD
############################################
echo "⚙️ Installing ArgoCD..."
kubectl create namespace argocd || true

kubectl apply -n argocd \
-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for ArgoCD..."
kubectl wait --for=condition=available deployment argocd-server -n argocd --timeout=180s

############################################
# 4. Create Namespace
############################################
kubectl create namespace fintech-dev || true

############################################
# 5. Deploy MongoDB
############################################
echo "🗄️ Deploying MongoDB..."

cat <<EOF > mongo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  namespace: fintech-dev
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
        - name: mongo-data
          mountPath: /data/db
      volumes:
      - name: mongo-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: fintech-dev
spec:
  selector:
    app: mongodb
  ports:
  - port: 27017
EOF

kubectl apply -f mongo.yaml

############################################
# 6. Deploy RabbitMQ
############################################
echo "🐇 Deploying RabbitMQ..."

cat <<EOF > rabbitmq.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: fintech-dev
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
  namespace: fintech-dev
spec:
  selector:
    app: rabbitmq
  ports:
  - port: 5672
  - port: 15672
EOF

kubectl apply -f rabbitmq.yaml

############################################
# 7. Deploy App via ArgoCD
############################################
echo "🚀 Deploying app via ArgoCD..."

argocd app create fintech \
--repo https://github.com/venkatkube/fintech-platform \
--path k8s/overlays/dev \
--dest-server https://kubernetes.default.svc \
--dest-namespace fintech-dev \
--sync-policy automated || true

############################################
# 8. Build & Load Image
############################################
echo "🐳 Building Docker image..."

cd txn-service
docker build -t txn-service:latest .
kind load docker-image txn-service:latest --name fintech

kubectl rollout restart deployment txn-service -n fintech-dev
cd ..

############################################
# 9. Create Ingress
############################################
echo "🌍 Creating ingress..."

cat <<EOF > ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fintech-ingress
  namespace: fintech-dev
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

kubectl apply -f ingress.yaml

############################################
# 10. Update Hosts File
############################################
echo "🖥️ Adding host entry..."
echo "127.0.0.1 fintech.local" | sudo tee -a /etc/hosts

############################################
# 11. Install Monitoring Stack
############################################
echo "📊 Installing Prometheus + Grafana..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
-n monitoring --create-namespace

############################################
# 12. Done
############################################
echo ""
echo "🎉 SETUP COMPLETE!"
echo ""
echo "👉 Access App:"
echo "http://fintech.local/health"
echo ""
echo "👉 Access Grafana:"
echo "kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80"
echo "http://localhost:3000 (admin / prom-operator)"
echo ""
echo "👉 Access ArgoCD:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""

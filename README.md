# 🚀 Fintech Platform (Production-Grade SRE Project)

This project demonstrates a **production-grade fintech transaction system** built using:

* Kubernetes (KinD)
* Terraform (Namespaces)
* Helm (Infra components)
* Kustomize (App overlays)
* ArgoCD (GitOps)
* GitHub Actions (CI/CD)
* MongoDB, RabbitMQ, Elasticsearch, Kibana
* HPA (Autoscaling)

---

# 🧠 Architecture Overview

* **Infra (Helm)**: MongoDB, RabbitMQ, Elasticsearch, Kibana, Filebeat
* **Application (Kustomize)**: txn-service
* **GitOps (ArgoCD)**: App-of-Apps pattern
* **CI/CD**: GitHub Actions builds & pushes images

---

# 🔧 0. Prerequisites

Ensure the following tools are installed:

```bash
docker --version
kubectl version --client
kind --version
helm version
terraform version
git --version
```

---

# 📥 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/fintech-platform.git
cd fintech-platform
```

---

# 🐳 2. Verify Docker

```bash
docker info
```

---

# ☸️ 3. Create KinD Cluster

```bash
kind create cluster --name fintech --config kind-config.yaml
```

Verify:

```bash
kubectl get nodes
```

---

# 📊 4. Install Metrics Server (Required for HPA)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Fix TLS (KinD):

```bash
kubectl patch deployment metrics-server -n kube-system \
--type='json' \
-p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

Verify:

```bash
kubectl get pods -n kube-system | grep metrics-server
```

---

# 🏗️ 5. Create Namespaces (Terraform)

```bash
cd infra/terraform

terraform init
terraform apply -auto-approve
```

Verify:

```bash
kubectl get ns
```

Expected:

* fintech-dev
* fintech-prod
* observability

---

# 📦 6. Add Helm Repositories

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add elastic https://helm.elastic.co
helm repo update
```

---

# 🚀 7. Install ArgoCD

```bash
kubectl create namespace argocd
```

```bash
kubectl apply -n argocd \
-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait:

```bash
kubectl get pods -n argocd
```

---

# 🔑 8. Access ArgoCD UI

Port forward:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open:

```
https://localhost:8080
```

Get admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
-o jsonpath="{.data.password}" | base64 -d
```

---

# 🚀 9. Deploy via GitOps

```bash
kubectl apply -f argocd/app-of-apps.yaml
```

---

# 🔍 10. Verify Deployments

```bash
kubectl get pods -A
```

Check namespaces:

```bash
kubectl get pods -n fintech-dev
kubectl get pods -n fintech-prod
kubectl get pods -n observability
```

---

# 📊 11. Verify HPA

```bash
kubectl get hpa -n fintech-dev
kubectl top pods -n fintech-dev
```

---

# 🌐 12. Access Transaction Service

```bash
kubectl port-forward svc/txn-service -n fintech-dev 8080:80
```

Test:

```bash
curl -X POST http://localhost:8080/transaction \
-H "Content-Type: application/json" \
-d '{"amount":100,"user":"test"}'
```

---

# 📈 13. Access Kibana (Logs)

```bash
kubectl port-forward svc/kibana -n observability 5601:5601
```

Open:

```
http://localhost:5601
```

---

# 🔍 14. Verify Logs

* Create index pattern in Kibana
* Search logs from `txn-service`

---

# 🧪 15. Load Test (HPA)

```bash
for i in {1..100}; do
  curl -X POST http://localhost:8080/transaction \
  -H "Content-Type: application/json" \
  -d '{"amount":100}';
done
```

Watch scaling:

```bash
kubectl get pods -n fintech-dev -w
```

---

# 💥 16. Failure Simulation

```bash
kubectl delete pod -n fintech-dev -l app=txn-service
```

Watch recovery:

```bash
kubectl get pods -n fintech-dev -w
```

---

# 🎯 Execution Flow Summary

1. Install tools
2. Create KinD cluster
3. Install metrics-server
4. Apply Terraform
5. Install ArgoCD
6. Deploy app-of-apps
7. Verify pods
8. Test API
9. Check logs (Kibana)
10. Test scaling

---

# 🚀 Outcome

You now have:

* GitOps-driven deployment (ArgoCD)
* Event-driven architecture (RabbitMQ)
* Observability stack (ELK)
* Autoscaling system (HPA)
* Resilient microservices

---

# 🔥 Next Steps (Recommended)

* Add RBAC
* Add NetworkPolicies
* Add ResourceQuotas
* Add Service Mesh (Istio)
* Add SLO dashboards

---

# 👨‍💻 Author

Venkatesh Tuniki

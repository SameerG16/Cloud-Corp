# Cloud-Corp 🚀  
### One-Click Multi-Cloud Deployment • Cost Comparison • CSP Auto-Switching • Terraform + Kubernetes Automation

Cloud-Corp is a fully automated multi-cloud deployment system designed to deploy your application on any cloud provider with **one click**.  
It intelligently compares cloud costs, creates infrastructure using Terraform, deploys your app inside Kubernetes containers, and automatically switches cloud providers if one fails.

This project gives you **zero-downtime, cost-optimized, multi-cloud resilience**.

---

## 🌐 Key Capabilities

### ✅ **One-Click Deployment**
A single command launches your entire infrastructure:
- Create VM (EC2 or equivalent)
- Install Kubernetes
- Deploy your application in containers

### ✅ **Cost Comparison Engine**
CloudCorp V3 compares costs of supported CSPs and chooses the cheapest or most optimal one automatically.

### ✅ **Auto CSP Switching**
Tenant Tenacious monitors the current CSP for:
- Outages  
- API failures  
- Deployment issues  

If a problem is detected, it instantly **switches providers** and redeploys—automatically.

### ✅ **Terraform-Powered Infrastructure**
AutoMatrix uses Terraform to:
- Provision VM instances  
- Configure networking & security  
- Install Docker + Kubernetes  
- Deploy containerized apps  

---

## ⚙️ Project Structure

| Component | Function |
|----------|----------|
| **CloudCorp V3** | Cost comparison + triggers deployment |
| **Tenant Tenacious** | Detects CSP issues & auto-switches providers |
| **AutoMatrix** | Terraform automation + Kubernetes deployment |
| `main.py / cloudcorp_V3.py` | Primary one-click execution logic |
| `tenant_tentious.sh` | CSP switch handler |
| `AutoMatrix/` | Terraform + provisioning files |
| Kubernetes YAMLs | App deployment containers |

---

## 🏗️ How It Works (Simple Flow)
CloudCorp V3 → Compare Costs → Select CSP

|
v
Tenant Tenacious → Monitor CSP → Switch if needed

|
v
AutoMatrix → Terraform Infra → Kubernetes Setup → App Deployment

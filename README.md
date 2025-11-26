# Complete Bank App Deployment Guide - End to End

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [Debugging Guide](#debugging-guide)
5. [Cost Calculation](#cost-calculation)
6. [Ingress Controller Setup](#ingress-controller-setup)
7. [Cleanup](#cleanup)

---

## 🎯 Prerequisites

### 1. **AWS Account Setup**
- ✅ Active AWS account with admin access
- ✅ AWS CLI installed and configured
- ✅ IAM user with programmatic access (Access Key + Secret Key)

**Required IAM Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "iam:*",
        "elasticloadbalancing:*",
        "autoscaling:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. **Local Machine / EC2 Instance Requirements**

**Software Installations:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y unzip curl wget git

# 1. Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# 2. Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform --version

# 3. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

# 4. Install Git
sudo apt install git -y
git --version
```

### 3. **AWS Configuration**
```bash
# Configure AWS credentials
aws configure
# Enter:
# AWS Access Key ID: AKIA***********
# AWS Secret Access Key: **********************
# Default region: us-east-1
# Default output format: json

# Verify configuration
aws sts get-caller-identity
```

### 4. **EC2 Key Pair (For SSH Access)**
```bash
# Option 1: Create via AWS Console
# Go to: EC2 → Key Pairs → Create Key Pair
# Name: awslogin (or any name)
# Download .pem file

# Option 2: Create via CLI
aws ec2 create-key-pair --key-name awslogin --query 'KeyMaterial' --output text > awslogin.pem
chmod 400 awslogin.pem
```

### 5. **Clone the Repository**
```bash
git clone https://github.com/jaiswaladi246/Multi-Tier-With-Database.git
cd Multi-Tier-With-Database
```

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                  │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐    │  │
│  │  │  Subnet 1 (AZ-1a)   │  │  Subnet 2 (AZ-1b)   │    │  │
│  │  │  10.0.0.0/24        │  │  10.0.1.0/24        │    │  │
│  │  │                     │  │                     │    │  │
│  │  │  ┌──────────────┐   │  │  ┌──────────────┐   │    │  │
│  │  │  │ Worker Node  │   │  │  │ Worker Node  │   │    │  │
│  │  │  │  t2.medium   │   │  │  │  t2.medium   │   │    │  │
│  │  │  │              │   │  │  │              │   │    │  │
│  │  │  │ ┌──────────┐ │   │  │  │ ┌──────────┐ │   │    │  │
│  │  │  │ │MySQL Pod │ │   │  │  │ │BankApp   │ │   │    │  │
│  │  │  │ │+ EBS Vol │ │   │  │  │ │Pod       │ │   │    │  │
│  │  │  │ └──────────┘ │   │  │  │ └──────────┘ │   │    │  │
│  │  │  └──────────────┘   │  │  └──────────────┘   │    │  │
│  │  └─────────────────────┘  └─────────────────────┘    │  │
│  │                                                        │  │
│  │         ┌──────────────────────────────┐              │  │
│  │         │   EKS Control Plane          │              │  │
│  │         │   (Managed by AWS)           │              │  │
│  │         └──────────────────────────────┘              │  │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────┐         ┌──────────────────┐           │
│  │ Classic Load   │────────▶│  Security Groups │           │
│  │ Balancer       │         └──────────────────┘           │
│  └────────────────┘                                         │
│         │                                                    │
│  ┌──────▼──────────┐                                        │
│  │  EBS Volumes    │                                        │
│  │  (gp3 5GB)      │                                        │
│  └─────────────────┘                                        │
└──────────────────────────────────────────────────────────────┘
         │
         ▼
    Users (Browser)
```

**Components:**
- **EKS Cluster**: Managed Kubernetes control plane
- **Node Group**: 3 x t2.medium worker nodes
- **VPC**: Isolated network with 2 subnets across 2 AZs
- **EBS CSI Driver**: Manages persistent storage for MySQL
- **LoadBalancer**: Exposes application to internet
- **MySQL**: Database with 5GB persistent EBS volume
- **BankApp**: Spring Boot application

---

## 🚀 Step-by-Step Deployment

### **PHASE 1: Infrastructure Deployment (Terraform)**

#### Step 1: Prepare Terraform Files
```bash
cd Terraform-Code

# Verify files exist
ls -la
# Should see: main.tf, variables.tf, output.tf
```

#### Step 2: Update Variables (If Needed)
```bash
nano variables.tf

# Set your SSH key name:
variable "ssh_key_name" {
  default     = "awslogin"  # Change to your key pair name
}
```

#### Step 3: Initialize Terraform
```bash
terraform init

# Output should show:
# Terraform has been successfully initialized!
```

#### Step 4: Review Infrastructure Plan
```bash
terraform plan

# Review what will be created:
# - VPC, Subnets, IGW, Route Tables
# - Security Groups
# - IAM Roles (Cluster, Node, EBS CSI)
# - OIDC Provider
# - EKS Cluster
# - EKS Node Group
# - EBS CSI Driver Addon
```

#### Step 5: Deploy Infrastructure
```bash
terraform apply -auto-approve

# ⏱️ Takes ~15-20 minutes
# Wait for: "Apply complete! Resources: 21 added"
```

#### Step 6: Save Outputs
```bash
terraform output

# Save these values:
# cluster_id = "devopsshack-cluster"
# vpc_id = "vpc-xxxxx"
# subnet_ids = ["subnet-xxxx", "subnet-yyyy"]
```

---

### **PHASE 2: Kubernetes Configuration**

#### Step 7: Configure kubectl
```bash
# Update kubeconfig to connect to EKS cluster
aws eks update-kubeconfig --name devopsshack-cluster --region us-east-1

# Verify connection
kubectl get nodes

# Expected output: 3 nodes in Ready state
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-0-132.ec2.internal   Ready    <none>   5m    v1.34.2-eks-ecaa3a6
# ip-10-0-0-149.ec2.internal   Ready    <none>   5m    v1.34.2-eks-ecaa3a6
# ip-10-0-1-57.ec2.internal    Ready    <none>   5m    v1.34.2-eks-ecaa3a6
```

#### Step 8: Verify EBS CSI Driver
```bash
# Check EBS CSI driver pods are running
kubectl get pods -n kube-system | grep ebs-csi

# Should see:
# ebs-csi-controller-xxx   6/6     Running
# ebs-csi-node-xxx         3/3     Running (one per node)
```

---

### **PHASE 3: Application Deployment**

#### Step 9: Review Application Manifests
```bash
cd ../Manifest-Code

# Check manifest2.yaml
cat manifest2.yaml

# Ensure it contains:
# - Secret (MySQL credentials)
# - ConfigMap (Database name)
# - StorageClass (EBS provisioner)
# - PVC (5GB storage request)
# - MySQL Deployment
# - MySQL Service
# - BankApp Deployment
# - BankApp LoadBalancer Service
```

#### Step 10: Deploy MySQL & Application
```bash
kubectl apply -f manifest2.yaml

# Output:
# secret/mysql-secret created
# configmap/mysql-config created
# storageclass.storage.k8s.io/ebs-sc created
# persistentvolumeclaim/mysql-pvc created
# deployment.apps/mysql created
# service/mysql-service created
# deployment.apps/bankapp created
# service/bankapp-service created
```

#### Step 11: Monitor Deployment
```bash
# Watch pods come up (Ctrl+C to exit)
kubectl get pods -w

# Wait until both pods show Running:
# NAME                       READY   STATUS    RESTARTS   AGE
# mysql-xxxxx                1/1     Running   0          2m
# bankapp-xxxxx              1/1     Running   0          1m
```

#### Step 12: Check PVC is Bound
```bash
kubectl get pvc

# Should show:
# NAME        STATUS   VOLUME                                     CAPACITY
# mysql-pvc   Bound    pvc-abc123-xxxx-xxxx-xxxx-xxxxxxxxxxxx    5Gi
```

#### Step 13: Verify EBS Volume Created in AWS
```bash
# List EBS volumes
aws ec2 describe-volumes --region us-east-1 \
  --filters "Name=tag:kubernetes.io/created-for/pvc/name,Values=mysql-pvc" \
  --query 'Volumes[*].[VolumeId,State,Size]' --output table

# Should show: vol-xxxxx | in-use | 5
```

#### Step 14: Get LoadBalancer URL
```bash
kubectl get svc bankapp-service

# Copy EXTERNAL-IP:
# NAME              TYPE           EXTERNAL-IP
# bankapp-service   LoadBalancer   a8bf206...elb.amazonaws.com
```

#### Step 15: Wait for LoadBalancer (2-3 minutes)
```bash
# Test when it's ready
LB_URL=$(kubectl get svc bankapp-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I http://$LB_URL

# Should return: HTTP/1.1 200 OK
```

#### Step 16: Access Application
```bash
# Open in browser
echo "http://$LB_URL"

# Or use curl
curl http://$LB_URL
```

---

### **PHASE 4: Verification & Testing**

#### Step 17: Check Application Logs
```bash
# BankApp logs
kubectl logs -l app=bankapp --tail=50

# MySQL logs
kubectl logs -l app=mysql --tail=50
```

#### Step 18: Verify MySQL Database
```bash
# Connect to MySQL pod
kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- /bin/bash

# Inside pod, connect to MySQL
mysql -u root -p$MYSQL_ROOT_PASSWORD

# In MySQL prompt:
SHOW DATABASES;
USE bankappdb;
SHOW TABLES;
EXIT;

# Exit pod
exit
```

#### Step 19: Test Application Functionality
```bash
# 1. Register a new user via browser
# 2. Login with credentials
# 3. Check account created in database

kubectl exec -it $(kubectl get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}') -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD -e "SELECT * FROM bankappdb.account;"
```

---

## 🐛 Debugging Guide - 25 Essential Steps

### **Level 1: Quick Health Checks**

#### 1. Check All Resources
```bash
kubectl get all
kubectl get all -A
```

#### 2. Check Nodes
```bash
kubectl get nodes
kubectl describe nodes
```

#### 3. Check System Pods
```bash
kubectl get pods -n kube-system
```

### **Level 2: Pod Debugging**

#### 4. Check Pod Status
```bash
kubectl get pods -o wide
```

#### 5. Describe Pod (Most Important!)
```bash
kubectl describe pod <pod-name>
# Check Events section at bottom
```

#### 6. Check Pod Logs
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # If restarted
kubectl logs <pod-name> -f          # Follow logs
```

#### 7. Execute Commands in Pod
```bash
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec <pod-name> -- env
```

### **Level 3: Network Debugging**

#### 8. Check Services
```bash
kubectl get svc
kubectl describe svc <service-name>
```

#### 9. Check Endpoints
```bash
kubectl get endpoints
# Endpoints should list pod IPs
```

#### 10. Test DNS Resolution
```bash
kubectl exec <pod-name> -- nslookup mysql-service
```

#### 11. Test Connectivity
```bash
# Create debug pod
kubectl run debug --image=busybox --rm -it --restart=Never -- sh

# Inside debug pod:
wget -O- http://bankapp-service
nslookup mysql-service
telnet mysql-service 3306
```

#### 12. Check Network Policies
```bash
kubectl get networkpolicies
```

### **Level 4: Storage Debugging**

#### 13. Check PVC Status
```bash
kubectl get pvc
kubectl describe pvc mysql-pvc
```

#### 14. Check PV Details
```bash
kubectl get pv
kubectl describe pv <pv-name>
```

#### 15. Check StorageClass
```bash
kubectl get storageclass
kubectl describe storageclass ebs-sc
```

#### 16. Check EBS CSI Driver Logs
```bash
kubectl logs -n kube-system -l app=ebs-csi-controller
kubectl logs -n kube-system -l app=ebs-csi-node
```

#### 17. Verify EBS Volume in AWS
```bash
aws ec2 describe-volumes --region us-east-1 \
  --filters "Name=tag:kubernetes.io/cluster/devopsshack-cluster,Values=owned"
```

### **Level 5: Configuration Debugging**

#### 18. Check Secrets
```bash
kubectl get secrets
kubectl get secret mysql-secret -o yaml
# Decode values:
kubectl get secret mysql-secret -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d
```

#### 19. Check ConfigMaps
```bash
kubectl get configmaps
kubectl describe configmap mysql-config
```

#### 20. Verify Environment Variables
```bash
kubectl exec <pod-name> -- env | grep -i mysql
```

### **Level 6: Deployment Debugging**

#### 21. Check Deployment Status
```bash
kubectl get deployments
kubectl describe deployment <deployment-name>
kubectl rollout status deployment/<deployment-name>
```

#### 22. Check ReplicaSets
```bash
kubectl get rs
kubectl describe rs <replicaset-name>
```

### **Level 7: Events & Monitoring**

#### 23. Check Cluster Events
```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --watch
```

#### 24. Check Resource Usage
```bash
kubectl top nodes
kubectl top pods
```

#### 25. Port Forwarding for Direct Access
```bash
# Forward local port to pod
kubectl port-forward pod/<pod-name> 8080:8080
# Access at http://localhost:8080

# Forward to service
kubectl port-forward svc/bankapp-service 8080:80
```

---

## 💰 Cost Calculation

### **Monthly Cost Breakdown (us-east-1 region)**

#### 1. **EKS Control Plane**
```
Cost: $0.10 per hour
Monthly: $0.10 × 24 × 30 = $72.00
```

#### 2. **EC2 Instances (Worker Nodes)**
```
Instance Type: t2.medium
vCPUs: 2
RAM: 4 GB
Cost per instance: $0.0464 per hour

Number of nodes: 3
Hourly: $0.0464 × 3 = $0.1392/hour
Daily: $0.1392 × 24 = $3.34/day
Monthly: $0.1392 × 24 × 30 = $100.22
```

#### 3. **EBS Volumes**
```
Volume Type: gp3
Size: 5 GB (for MySQL)
Cost: $0.08 per GB-month
Monthly: $0.08 × 5 = $0.40

Node root volumes: 3 × 20 GB = 60 GB
Monthly: $0.08 × 60 = $4.80

Total EBS: $5.20/month
```

#### 4. **Classic Load Balancer**
```
Hourly: $0.025 per hour
Data Processing: $0.008 per GB

Monthly: $0.025 × 24 × 30 = $18.00
Data (estimate 10GB/month): $0.008 × 10 = $0.08
Total LB: $18.08/month
```

#### 5. **Data Transfer**
```
First 1 GB out: FREE
Next 9.999 TB: $0.09 per GB
Estimate: 5 GB/month = $0.45
```

#### 6. **NAT Gateway (if using private subnets)**
```
Hourly: $0.045 per hour
Data Processing: $0.045 per GB

Note: Current setup uses public subnets, so NAT Gateway = $0
```

### **Total Cost Summary**

| Component | Hourly | Daily | Monthly |
|-----------|--------|-------|---------|
| EKS Control Plane | $0.10 | $2.40 | $72.00 |
| EC2 Nodes (3×) | $0.14 | $3.34 | $100.22 |
| EBS Volumes | - | $0.17 | $5.20 |
| Load Balancer | $0.03 | $0.60 | $18.08 |
| Data Transfer | - | $0.02 | $0.45 |
| **TOTAL** | **$0.27** | **$6.53** | **$195.95** |

### **Cost Optimization Tips**

#### **Save 50-70% with:**

1. **Use Spot Instances**
```hcl
# In Terraform main.tf
resource "aws_eks_node_group" "devopsshack" {
  capacity_type = "SPOT"
  instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
}
# Savings: ~70% on EC2 costs
```

2. **Use Fargate (Serverless)**
```bash
# Pay only when pods are running
# No idle node costs
# Cost: $0.04048/vCPU/hour + $0.004445/GB/hour
```

3. **Scale Down During Off-Hours**
```bash
# Scale to 1 node at night
kubectl scale deployment bankapp --replicas=0
terraform apply -var="node_count=1"
```

4. **Use t3.small instead of t2.medium**
```
t2.medium: $0.0464/hour
t3.small:  $0.0208/hour (55% cheaper)
```

5. **Use Reserved Instances (1-year commitment)**
```
Savings: 40% discount on EC2
Monthly: $100.22 → $60.13
```

### **Development/Testing Cost Reduction**

```bash
# Work only 8 hours/day, 5 days/week
Weekly hours: 40
Monthly hours: 160 (instead of 720)

Reduced cost: $195.95 × (160/720) = $43.54/month
```

---

## 🌐 Ingress Controller Setup

### **Why Use Ingress Instead of LoadBalancer?**

**LoadBalancer Service Issues:**
- ✅ Each service creates a separate AWS ELB ($18/month each)
- ✅ Multiple services = Multiple ELBs = High cost
- ✅ No SSL/TLS termination
- ✅ No path-based routing
- ✅ No host-based routing

**Ingress Controller Benefits:**
- ✅ Single Load Balancer for all services
- ✅ SSL/TLS termination
- ✅ Path-based routing (/api → backend, / → frontend)
- ✅ Host-based routing (api.example.com, www.example.com)
- ✅ Better cost efficiency

---

### **Option 1: AWS Load Balancer Controller (Recommended)**

#### Step 1: Install AWS Load Balancer Controller

```bash
# 1. Create IAM OIDC provider (already done in Terraform)
# Verify it exists:
aws eks describe-cluster --name devopsshack-cluster --query "cluster.identity.oidc.issuer" --output text

# 2. Download IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

# 3. Create IAM policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

# 4. Create IAM role and service account
eksctl create iamserviceaccount \
  --cluster=devopsshack-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT-ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# 5. Install AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=devopsshack-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# 6. Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

#### Step 2: Convert Service to ClusterIP

```bash
# Edit manifest2.yaml
nano manifest2.yaml
```

Change LoadBalancer to ClusterIP:
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: bankapp-service
spec:
  type: ClusterIP  # Changed from LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: bankapp
```

#### Step 3: Create Ingress Resource

```bash
# Create ingress.yaml
cat > ingress.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bankapp-ingress
  annotations:
    # AWS ALB specific annotations
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: bankapp-service
                port:
                  number: 80
EOF

kubectl apply -f ingress.yaml
```

#### Step 4: Get ALB URL

```bash
# Wait for ALB to provision (2-3 minutes)
kubectl get ingress bankapp-ingress

# Get ALB URL
kubectl get ingress bankapp-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

### **Option 2: NGINX Ingress Controller**

#### Step 1: Install NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/aws/deploy.yaml

# Verify installation
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

#### Step 2: Create Ingress Resource

```bash
cat > ingress-nginx.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bankapp-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: bankapp-service
                port:
                  number: 80
EOF

kubectl apply -f ingress-nginx.yaml
```

---

### **Ingress with SSL/TLS (HTTPS)**

#### Step 1: Request SSL Certificate from AWS ACM

```bash
# Request certificate for your domain
aws acm request-certificate \
  --domain-name bankapp.example.com \
  --validation-method DNS \
  --region us-east-1

# Validate via DNS (add CNAME record in Route53)
```

#### Step 2: Update Ingress with SSL

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bankapp-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT-ID
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
    - host: bankapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: bankapp-service
                port:
                  number: 80
```

---

### **Path-Based Routing Example**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-path-ingress
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend-service
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 80
```

---

### **Host-Based Routing Example**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host-ingress
spec:
  ingressClassName: alb
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 8080
    - host: www.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
```

---

## 🧹 Cleanup

### **Delete Kubernetes Resources**

```bash
# Delete application
kubectl delete -f manifest2.yaml

# Delete ingress (if created)
kubectl delete -f ingress.yaml

# Verify all resources deleted
kubectl get all
kubectl get pvc,pv
```

### **Delete AWS Infrastructure**

```bash
cd Terraform-Code

# Destroy everything
terraform destroy -auto-approve

# ⏱️ Takes ~10-15 minutes
```

### **Verify Cleanup**

```bash
# Check no EKS clusters
aws eks list-clusters --region us-east-1

# Check no EBS volumes
aws ec2 describe-volumes --region us-east-1 \
  --filters "Name=tag:kubernetes.io/cluster/devopsshack-cluster,Values=owned"

# Check no load balancers
aws elb describe-load-balancers --region us-east-1
```

---

## 📚 Additional Resources

### **Useful Commands**

```bash
# Get kubeconfig
aws eks update-kubeconfig --name devopsshack-cluster --region us-east-1

# Switch context
kubectl config use-context arn:aws:eks:us-east-1:ACCOUNT:cluster/devopsshack-cluster

# View current context
kubectl config current-context

# Create namespace
kubectl create namespace production

# Set default namespace
kubectl config set-context --current --namespace=production

# Export YAML
kubectl get deployment bankapp -o yaml > bankapp-backup.yaml

# Apply with dry-run
kubectl apply -f manifest.yaml --dry-run=client

# Delete with force
kubectl delete pod <pod-name> --force --grace-period=0
```

### **Monitoring & Observability**

```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Check metrics
kubectl top nodes
kubectl top pods --all-namespaces

# Watch resources
watch kubectl get pods
```

### **Troubleshooting Quick Reference**

| Issue | Command |
|-------|---------|
| Pod not starting | `kubectl describe pod <pod>` |
| Check logs | `kubectl logs <pod> --previous` |
| Service not accessible | `kubectl get endpoints <svc>` |
| Storage issues | `kubectl describe pvc <pvc>` |
| Network issues | `kubectl exec <pod> -- nslookup <svc>` |
| Events | `kubectl get events --sort-by='.lastTimestamp'` |

---

## 🎯 Success Checklist

- [ ] AWS CLI configured with valid credentials
- [ ] Terraform installed and initialized
- [ ] kubectl installed and configured
- [ ] EC2 Key Pair created (if using SSH)
- [ ] Terraform apply completed successfully (21 resources)
- [ ] 3 nodes in Ready state
- [ ] EBS CSI driver pods running
- [ ] MySQL pod running with PVC bound
- [ ] BankApp pod running without crashes
- [ ] LoadBalancer or Ingress accessible
- [ ] Application accessible via browser
- [ ] Database tables created
- [ ] User registration working
- [ ] Login functionality working
- [ ] Transactions visible in database

---

## 🆘 Support & Help

**Common Issues:**

1. **Terraform apply fails** → Check AWS credentials and IAM permissions
2. **Node group creation fails** → Verify SSH key exists in AWS
3. **EBS CSI driver degraded** → Check IAM role and OIDC provider
4. **Pods in CrashLoopBackOff** → Check logs: `kubectl logs <pod> --previous`
5. **LoadBalancer pending** → Wait 2-3 minutes for AWS ELB provisioning
6. **Can't connect to MySQL** → Verify `allowPublicKeyRetrieval=true` in JDBC URL

**Get Help:**
- GitHub Issues: https://github.com/jaiswaladi246/Multi-Tier-With-Database/issues
- AWS EKS Documentation: https://docs.aws.amazon.com/eks/
- Kubernetes Documentation: https://kubernetes.io/docs/

---

**Created by:** GitHub Copilot  
**Last Updated:** November 26, 2025  
**Version:** 1.0

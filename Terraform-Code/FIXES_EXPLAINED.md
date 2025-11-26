# EKS Cluster Issues - Fixed ✅

## What Were the Problems?

### 1. **EBS CSI Driver in DEGRADED State**
**Why it happened:** The EBS CSI driver addon needs special IAM permissions to create and manage EBS volumes for your Kubernetes persistent volumes. Without proper IRSA (IAM Roles for Service Accounts) configuration, it cannot function properly.

**What was fixed:**
- ✅ Created an OIDC provider for the EKS cluster
- ✅ Created a dedicated IAM role for the EBS CSI driver with proper trust policy
- ✅ Attached the AmazonEBSCSIDriverPolicy to this role
- ✅ Linked the IAM role to the addon via `service_account_role_arn`
- ✅ Added proper dependencies to ensure resources are created in the right order

### 2. **KeyPair "customisegroup" Not Found**
**Why it happened:** You specified an SSH key name that doesn't exist in your AWS account. AWS was trying to use this key for SSH access to the worker nodes but couldn't find it.

**What was fixed:**
- ✅ Made SSH key optional by using a dynamic block
- ✅ Changed default value to empty string
- ✅ SSH access is now disabled by default (more secure)
- ✅ You can still enable it by providing a valid key name if needed

## How to Deploy Now

### Option 1: Deploy Without SSH Access (Recommended for Production)
```powershell
cd d:\Devops\Mega-Project-1\bankapp-mysql-deployment\Terraform-Code
terraform init
terraform plan
terraform apply
```

### Option 2: Deploy With SSH Access
First, create an SSH key pair in AWS:
1. Go to AWS Console → EC2 → Key Pairs
2. Click "Create key pair"
3. Name it (e.g., "my-eks-key")
4. Download the .pem file

Then deploy with the key:
```powershell
terraform apply -var="ssh_key_name=my-eks-key"
```

## What Changed in the Code

### New Resources Added:
- **OIDC Provider** - Enables IAM roles for Kubernetes service accounts
- **EBS CSI Driver IAM Role** - Dedicated role with proper permissions
- **TLS Certificate Data Source** - Gets OIDC provider thumbprint

### Modified Resources:
- **EBS CSI Addon** - Now has `service_account_role_arn` and proper dependencies
- **Node Group** - SSH access is now optional via dynamic block
- **Variables** - SSH key default changed to empty string

## Cleanup (If You Need to Start Fresh)

If you already have a partially created cluster:
```powershell
terraform destroy
```

Then run `terraform apply` again with the fixed code.

## Testing After Deployment

Once deployed, verify the EBS CSI driver is working:
```powershell
# Update kubeconfig
aws eks update-kubeconfig --name devopsshack-cluster --region us-east-1

# Check addon status
kubectl get pods -n kube-system | Select-String "ebs-csi"

# Should show ebs-csi-controller and ebs-csi-node pods running
```

## Understanding IRSA (IAM Roles for Service Accounts)

This is how AWS EKS addons securely access AWS services:
1. **OIDC Provider** - Acts as a bridge between Kubernetes and AWS IAM
2. **IAM Role** - Defines what permissions the addon has
3. **Service Account** - Kubernetes identity that assumes the IAM role
4. **Addon** - Uses the service account to make AWS API calls

Without this setup, the EBS CSI driver cannot create/attach/detach EBS volumes!

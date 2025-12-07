#!/bin/bash

echo "=============================="
echo "     AutoMatrix AWS Deploy    "
echo "=============================="

# --- User Inputs ---
read -p "Enter GitHub repo URL (default Flask Hello World): " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-"https://github.com/pallets/flask.git"}

read -p "Enter app container port (example 8080): " APP_PORT
APP_PORT=${APP_PORT:-8080}

read -p "Enter number of replicas/pods: " REPLICAS
REPLICAS=${REPLICAS:-3}

read -p "Enter app name (no spaces): " APP_NAME
APP_NAME=${APP_NAME:-automatrix}

read -p "Enter AWS Key Pair name: " KEY_NAME
KEY_NAME=${KEY_NAME:-automatrix_key}

read -p "Enter Security Group name: " SG_NAME
SG_NAME=${SG_NAME:-automatrix_sg}

# --- Create Terraform Directory ---
mkdir -p automatrix-aws
cd automatrix-aws || exit

# --- Generate Terraform Config ---
cat <<EOF > main.tf
variable "key_name" { default = "$KEY_NAME" }
variable "sg_name" { default = "$SG_NAME" }

provider "aws" {
  region = "ap-south-1"
}

resource "tls_private_key" "auto_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "auto_key" {
  key_name   = var.key_name
  public_key = tls_private_key.auto_key.public_key_openssh
}

resource "aws_security_group" "auto_sg" {
  name        = var.sg_name
  description = "Auto-generated SG for AutoMatrix app"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "auto_instance" {
  ami                         = "ami-052c08d70def0ac62" # Ubuntu 22.04 in ap-south-1
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.auto_key.key_name
  vpc_security_group_ids      = [aws_security_group.auto_sg.id]
  associate_public_ip_address = true
  tags = { Name = "$APP_NAME-EC2" }
}

output "ec2_public_ip" {
  value = aws_instance.auto_instance.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.auto_key.private_key_pem
  sensitive = true
}
EOF

# --- Terraform Deploy ---
terraform init
terraform apply -auto-approve

# --- Save Private Key ---
terraform output -raw private_key_pem > $KEY_NAME.pem
chmod 400 $KEY_NAME.pem

# --- Get EC2 Public IP ---
EC2_IP=$(terraform output -raw ec2_public_ip)
echo "EC2 Public IP: $EC2_IP"

# --- Wait for SSH ---
echo "Waiting for SSH to become available..."
while ! ssh -o StrictHostKeyChecking=no -i $KEY_NAME.pem ubuntu@$EC2_IP 'echo SSH ready' &>/dev/null; do
    sleep 5
done
echo "SSH is ready!"

# --- Remote Deploy Script ---
ssh -o StrictHostKeyChecking=no -i $KEY_NAME.pem ubuntu@$EC2_IP bash <<EOD
sudo apt update && sudo apt install -y git docker.io curl unzip
sudo systemctl start docker
sudo systemctl enable docker

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Clone App Repo
rm -rf $APP_NAME
git clone $GITHUB_REPO $APP_NAME
cd $APP_NAME

# Build Docker Image
docker build -t $APP_NAME:latest .

# Create Kind Cluster
kind create cluster --name $APP_NAME

# Load Docker Image into Kind
kind load docker-image $APP_NAME:latest --name $APP_NAME

# Generate K8s YAML
mkdir -p k8s
cat <<EOF > k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
spec:
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
        - name: $APP_NAME
          image: $APP_NAME:latest
          ports:
            - containerPort: $APP_PORT
EOF

NODE_PORT=$((30000 + $APP_PORT % 2768))
cat <<EOF > k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME-service
spec:
  type: NodePort
  selector:
    app: $APP_NAME
  ports:
    - port: $APP_PORT
      targetPort: $APP_PORT
      nodePort: $NODE_PORT
EOF

# Deploy to K8s
kubectl apply -f k8s/

# Show Status
kubectl get pods
kubectl get svc
EOD

echo "Deployment complete! Access your app at http://$EC2_IP:$NODE_PORT"

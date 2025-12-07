#!/bin/bash

echo "============================================"
echo "        AUTOMATRIX DEPLOYMENT TOOL"
echo "============================================"

# --- Environment choice ---
echo "Choose deployment environment:"
echo "1) Local (Docker + Kubernetes)"
echo "2) AWS EC2 (Terraform + Kubernetes)"
read -p "Enter option [1/2] (default 1): " option
option=${option:-1}

##############################################
# FUNCTIONS
##############################################

generate_ssh_key() {
    echo "[+] Generating SSH key..."
    if [ ! -f id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f id_rsa -N ""
    else
        echo "[*] SSH key already exists."
    fi
}

create_terraform_files() {
echo "[+] Creating Terraform config..."

mkdir -p terraform
cat <<EOF > terraform/main.tf
provider "aws" {
  region = "ap-south-1"
}

resource "aws_key_pair" "auto_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "auto_sg" {
  name        = var.sg_name
  description = "Auto SG for Automatrix"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "auto_ec2" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.auto_key.key_name

  vpc_security_group_ids = [aws_security_group.auto_sg.id]

  tags = {
    Name = "AutoMatrixEC2"
  }
}

output "instance_public_ip" {
  value = aws_instance.auto_ec2.public_ip
}
EOF

cat <<EOF > terraform/variables.tf
variable "key_name" {
  default = "auto_key"
}

variable "public_key_path" {
  default = "id_rsa.pub"
}

variable "sg_name" {
  default = "auto_sg"
}
EOF
}

create_k8s_files() {
echo "[+] Creating Kubernetes YAML..."

mkdir -p k8s

cat <<EOF > k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app_name
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: $app_name
  template:
    metadata:
      labels:
        app: $app_name
    spec:
      containers:
      - name: $app_name
        image: $app_name:latest
        ports:
        - containerPort: $port
EOF

cat <<EOF > k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: $app_name-service
spec:
  type: NodePort
  selector:
    app: $app_name
  ports:
    - port: $port
      targetPort: $port
      nodePort: 30080
EOF
}

local_deploy() {
    echo "[+] Local deployment selected."

    read -p "Enter GitHub Repo URL (default https://github.com/pallets/flask.git): " repo
    repo=${repo:-https://github.com/pallets/flask.git}

    read -p "Enter app port (default 8080): " port
    port=${port:-8080}

    read -p "Enter number of replicas (default 3): " replicas
    replicas=${replicas:-3}

    read -p "Enter app name (default automatrix): " app_name
    app_name=${app_name:-automatrix}

    echo "[+] Cloning GitHub Repo..."
    mkdir -p $app_name
    cd $app_name || exit
    rm -rf app
    git clone $repo app

    echo "[+] Building Docker image..."
    sudo docker build -t "$app_name:latest" ./app

    echo "[+] Creating Kubernetes files..."
    create_k8s_files

    echo "[+] Deploying to Kubernetes..."
    kubectl apply -f k8s/

    echo "[+] Deployment complete!"
    kubectl get pods
    kubectl get svc
}

aws_deploy() {
    echo "[+] AWS deployment selected."

    read -p "Enter GitHub Repo URL (default https://github.com/pallets/flask.git): " repo
    repo=${repo:-https://github.com/pallets/flask.git}

    read -p "Enter app port (default 8080): " port
    port=${port:-8080}

    read -p "Enter number of replicas (default 3): " replicas
    replicas=${replicas:-3}

    read -p "Enter app name (default automatrix): " app_name
    app_name=${app_name:-automatrix}

    generate_ssh_key
    create_terraform_files

    cd terraform || exit

    echo "[+] Initializing Terraform..."
    terraform init
    terraform validate
    terraform apply -auto-approve

    PUBLIC_IP=$(terraform output -raw instance_public_ip)
    echo "[+] EC2 launched at: $PUBLIC_IP"
    echo "[+] Waiting 40 seconds for EC2 to be ready..."
    sleep 40

    echo "[+] Connecting to EC2 to deploy app..."
ssh -o StrictHostKeyChecking=no -i ../id_rsa ubuntu@$PUBLIC_IP <<EOF
sudo apt update -y
sudo apt install -y git docker.io snapd
sudo snap install kubectl --classic

git clone $repo app
cd app
sudo docker build -t $app_name:latest .

mkdir -p k8s

cat <<EOL > k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $app_name
spec:
  replicas: $replicas
  selector:
    matchLabels:
      app: $app_name
  template:
    metadata:
      labels:
        app: $app_name
    spec:
      containers:
      - name: $app_name
        image: $app_name:latest
        ports:
        - containerPort: $port
EOL

cat <<EOL > k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: $app_name-service
spec:
  type: NodePort
  selector:
    app: $app_name
  ports:
    - port: $port
      targetPort: $port
      nodePort: 30080
EOL

sudo kubectl apply -f k8s/
sudo kubectl get pods
sudo kubectl get svc
EOF

    echo "[+] AWS Deployment complete! Access your app at http://$PUBLIC_IP:30080"
}

##############################################
# MAIN LOGIC
##############################################

if [ "$option" == "1" ]; then
    local_deploy
elif [ "$option" == "2" ]; then
    aws_deploy
else
    echo "Invalid option!"
fi

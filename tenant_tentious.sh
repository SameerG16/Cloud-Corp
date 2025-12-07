#!/bin/bash

echo "=== Tenant Tentious Starting ==="

AWS_REGION="ap-south-1"
AWS_KEY_NAME="tenantKey"
AWS_SG_NAME="tenant-sg"

GCP_ZONE="us-central1-a"

KEY_PATH="$HOME/.ssh/tenant_key"
PUB_KEY_PATH="$HOME/.ssh/tenant_key.pub"

########################################
# 1) SSH KEY
########################################

if [ ! -f "$KEY_PATH" ]; then
    echo "Creating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N ""
fi

########################################
# 2) AWS SECURITY GROUP
########################################

echo "Creating AWS Security Group..."

SG_ID=$(aws ec2 create-security-group \
  --group-name "$AWS_SG_NAME" \
  --description "Tenant Tentious SG" \
  --region "$AWS_REGION" \
  --query 'GroupId' \
  --output text)

echo "AWS SG: $SG_ID"

aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$AWS_REGION"

########################################
# 3) AWS KEY PAIR
########################################

echo "Importing AWS key pair..."
aws ec2 import-key-pair \
  --region "$AWS_REGION" \
  --key-name "$AWS_KEY_NAME" \
  --public-key-material fileb://$PUB_KEY_PATH >/dev/null

########################################
# 4) LAUNCH AWS EC2 (FIXED AMI FOR MUMBAI)
########################################

echo "Launching AWS EC2..."

aws ec2 run-instances \
  --image-id ami-0ad704c126371a549 \
  --instance-type t2.micro \
  --region "$AWS_REGION" \
  --key-name "$AWS_KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=TenantAWS}]' >/dev/null

sleep 10

AWS_IP=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=TenantAWS" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

echo "AWS IP: $AWS_IP"

########################################
# 5) LAUNCH GCP VM (FIXED IMAGE FAMILY)
########################################

echo "Launching GCP VM..."

gcloud compute instances create tenant-gcp \
  --zone=$GCP_ZONE \
  --machine-type=e2-micro \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --metadata=ssh-keys="ubuntu:$(cat $PUB_KEY_PATH)" >/dev/null

GCP_IP=$(gcloud compute instances describe tenant-gcp \
  --zone=$GCP_ZONE \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "GCP IP: $GCP_IP"

########################################
# 6) INSTALL NGINX ON AWS & GCP
########################################

echo "Installing Nginx on AWS..."
ssh -o StrictHostKeyChecking=no -i $KEY_PATH ubuntu@$AWS_IP "sudo apt update -y && sudo apt install nginx -y && echo 'Hello from AWS Tenant Tentious' | sudo tee /var/www/html/index.html"

echo "Installing Nginx on GCP..."
ssh -o StrictHostKeyChecking=no -i $KEY_PATH ubuntu@$GCP_IP "sudo apt update -y && sudo apt install nginx -y && echo 'Hello from GCP Tenant Tentious' | sudo tee /var/www/html/index.html"

########################################
# 7) FAILOVER MONITOR
########################################

echo "=== Starting FAILOVER MONITOR ==="
echo "Active Server: AWS ($AWS_IP)"
echo "Backup Server: GCP ($GCP_IP)"
echo "----------------------------------"

while true; do

    if curl -s --max-time 3 http://$AWS_IP >/dev/null; then
        echo "[OK] AWS is UP"
    else
        echo "[FAIL] AWS is DOWN → Switching to GCP"
        echo "Open your browser at:"
        echo "http://$GCP_IP"
        exit 0
    fi

    sleep 5

done

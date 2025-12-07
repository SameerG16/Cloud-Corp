#!/bin/bash

echo "=============================="
echo "     AutoMatrix Full Setup     "
echo "=============================="

# ------------------------------
# Update system
# ------------------------------
sudo apt update && sudo apt upgrade -y

# ------------------------------
# 1. Install Git
# ------------------------------
echo "Installing Git..."
sudo apt install -y git

# ------------------------------
# 2. Install Docker
# ------------------------------
echo "Installing Docker..."
sudo apt remove -y docker docker-engine docker.io containerd runc
sudo apt install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add current user to Docker group
sudo usermod -aG docker $USER

# ------------------------------
# 3. Install Kind
# ------------------------------
echo "Installing Kind..."
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.25.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# ------------------------------
# 4. Install kubectl
# ------------------------------
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# ------------------------------
# 5. Install Python3 + pip
# ------------------------------
echo "Installing Python3 and pip..."
sudo apt install -y python3 python3-pip

# ------------------------------
# 6. Optional: Terraform
# ------------------------------
read -p "Do you want to install Terraform? (y/n): " INSTALL_TF
if [[ "$INSTALL_TF" == "y" || "$INSTALL_TF" == "Y" ]]; then
    echo "Installing Terraform..."
    sudo apt install -y gnupg software-properties-common curl
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt install -y terraform
fi

# ------------------------------
# 7. Auto-check versions
# ------------------------------
echo ""
echo "=============================="
echo "       Checking Versions       "
echo "=============================="
echo "Git version:"
git --version
echo "Docker version:"
docker --version
echo "Kind version:"
kind --version
echo "kubectl version:"
kubectl version --client --short
echo "Python version:"
python3 --version
echo "Pip version:"
pip3 --version
if [[ "$INSTALL_TF" == "y" || "$INSTALL_TF" == "Y" ]]; then
    echo "Terraform version:"
    terraform -v
fi

echo ""
echo "=============================="
echo "      Setup Complete!          "
echo "=============================="
echo "Please log out and log back in to apply Docker group changes."
echo "Your machine is now ready to run AutoMatrix deployment script."

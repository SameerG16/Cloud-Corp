import subprocess
import json
import requests

print("🌩️  CloudCorp v2 — Multi-Cloud Cost Comparator\n")

# ---------- AWS ----------
def get_aws_ec2_price(instance_type):
    try:
        cmd = (
            f"aws pricing get-products --service-code AmazonEC2 "
            f"--filters Type=TERM_MATCH,Field=instanceType,Value={instance_type} "
            f"Type=TERM_MATCH,Field=location,Value='US East (N. Virginia)' "
            f"--region us-east-1 --output json --max-results 1"
        )
        output = subprocess.check_output(cmd, shell=True)
        data = json.loads(output)
        price_str = data["PriceList"][0]
        price_json = json.loads(price_str)
        on_demand = list(price_json["terms"]["OnDemand"].values())[0]
        price_dimensions = list(on_demand["priceDimensions"].values())[0]
        usd_price = float(price_dimensions["pricePerUnit"]["USD"])
        return usd_price
    except Exception as e:
        print(f"[AWS] Error fetching EC2 {instance_type}: {e}")
        return None


def get_aws_vpn_price():
    # Static — AWS Site-to-Site VPN = $0.05/hour
    return 0.05


def get_aws_storage_price():
    # Example: S3 Standard storage = $0.023/GB-month
    return 0.023


# ---------- Azure ----------
def get_azure_vm_price(sku_name):
    try:
        url = f"https://prices.azure.com/api/retail/prices?$filter=serviceName eq 'Virtual Machines' and armSkuName eq '{sku_name}'"
        res = requests.get(url)
        data = res.json()
        if "Items" in data and len(data["Items"]) > 0:
            return float(data["Items"][0]["retailPrice"])
        return None
    except Exception as e:
        print(f"[Azure] Error fetching VM {sku_name}: {e}")
        return None


def get_azure_vpn_price():
    # Approx: Azure VPN Gateway Basic = $0.04/hour
    return 0.04


def get_azure_storage_price():
    # Example: Azure Blob Storage Hot Tier = $0.0184/GB-month
    return 0.0184


# ---------- GCP ----------
def get_gcp_vm_price(machine_type="e2-micro", region="us-central1"):
    try:
        cmd = (
            f"gcloud compute machine-types describe {machine_type} "
            f"--zone={region}-a --format=json"
        )
        subprocess.check_output(cmd, shell=True)  # just test availability
        # Static example: e2-micro = $0.0076/hour
        gcp_prices = {"e2-micro": 0.0076, "e2-medium": 0.026, "n1-standard-1": 0.0475}
        return gcp_prices.get(machine_type, 0.02)
    except Exception as e:
        print(f"[GCP] Error fetching {machine_type}: {e}")
        return None


def get_gcp_vpn_price():
    # Static: GCP Cloud VPN = $0.05/hour
    return 0.05


def get_gcp_storage_price():
    # Example: GCP Storage Standard = $0.020/GB-month
    return 0.020


# ---------- Input ----------
print("Choose services to compare (comma separated):")
print("Options: ec2, vpn, storage")
choices = input("👉 Enter services: ").strip().lower().split(",")

# ---------- Comparison ----------
def print_table(title, data):
    print(f"\n💰 {title} (USD):")
    print("------------------------------------------------")
    print(f"{'Service':<15} {'AWS':<10} {'Azure':<10} {'GCP':<10}")
    print("------------------------------------------------")
    for svc, prices in data.items():
        aws, az, gcp = prices
        print(f"{svc:<15} {aws if aws else '-':<10} {az if az else '-':<10} {gcp if gcp else '-':<10}")
    print("------------------------------------------------")


results = {}

if "ec2" in choices:
    aws_price = get_aws_ec2_price("t2.micro")
    az_price = get_azure_vm_price("Basic_A1")
    gcp_price = get_gcp_vm_price("e2-micro")
    results["EC2/VM"] = (aws_price, az_price, gcp_price)

if "vpn" in choices:
    results["VPN"] = (get_aws_vpn_price(), get_azure_vpn_price(), get_gcp_vpn_price())

if "storage" in choices:
    results["Storage (per GB)"] = (get_aws_storage_price(), get_azure_storage_price(), get_gcp_storage_price())

# ---------- Output ----------
print_table("Multi-Cloud Cost Comparison", results)

# ---------- Lowest Provider ----------
def get_lowest(provider_data):
    min_price = float("inf")
    best_provider = None
    for provider, price in provider_data.items():
        if price is not None and price < min_price:
            min_price = price
            best_provider = provider
    return best_provider, min_price


print("\n🏆 Cheapest Providers per Service:")
for svc, (aws, az, gcp) in results.items():
    provider_data = {"AWS": aws, "Azure": az, "GCP": gcp}
    best, cost = get_lowest(provider_data)
    if best:
        print(f"{svc:<15}: {best} @ ${cost}/hr")
    else:
        print(f"{svc:<15}: No valid data found")
# ---------- AWS DEPLOYMENT FEATURE ----------

def deploy_aws_instance():
    print("\n🚀 AWS Deployment Wizard")
    print("You will now deploy an EC2 instance using AWS CLI.\n")

    # ---- Instance Type ----
    instance_type = input("Enter EC2 instance type (default = t2.micro): ").strip()
    if instance_type == "":
        instance_type = "t2.micro"

    # ---- AWS Region ----
    print("\nChoose AWS Region:")
    regions = {
        "1": "us-east-1",
        "2": "us-west-1",
        "3": "eu-west-1",
        "4": "ap-south-1"
    }

    for k, v in regions.items():
        print(f"{k}. {v}")

    region_choice = input("Select region number: ").strip()
    region = regions.get(region_choice, "us-east-1")

    # ---- AMI ----
    default_amis = {
        "us-east-1": "ami-0fc5d935ebf8bc3bc",
        "us-west-1": "ami-0f8e81a3da6e2510a",
        "eu-west-1": "ami-00c90dbdc12232b58",
        "ap-south-1": "ami-0dee22c13ea7a9a67"
    }

    ami_id = input(f"Enter AMI ID (default = Ubuntu {default_amis.get(region)}): ").strip()
    if ami_id == "":
        ami_id = default_amis.get(region)

    # ---- Storage ----
    storage = input("Enter storage size in GB (default = 8): ").strip()
    if storage == "":
        storage = "8"

    # ---- Key Pair ----
    key_name = input("Enter AWS key-pair name: ").strip()

    # ---- Security Group ----
    sg_id = input("Enter Security Group ID: ").strip()

    # ---- Final Command ----
    print("\n⏳ Deploying EC2 instance...")

    try:
        cmd = (
            f"aws ec2 run-instances "
            f"--image-id {ami_id} "
            f"--count 1 "
            f"--instance-type {instance_type} "
            f"--key-name {key_name} "
            f"--security-group-ids {sg_id} "
            f"--block-device-mappings "
            f"DeviceName=/dev/sda1,Ebs={{VolumeSize={storage}}} "
            f"--region {region}"
        )

        output = subprocess.check_output(cmd, shell=True).decode()
        print("\n🎉 EC2 Instance Launched Successfully!")
        print(output)

    except Exception as e:
        print(f"❌ Deployment failed: {e}")


# ---------- ASK IF USER WANTS TO DEPLOY ----------
deploy_choice = input("\n⚡ Do you want to deploy an AWS EC2 instance? (y/n): ").strip().lower()

if deploy_choice == "y":
    deploy_aws_instance()
else:
    print("👍 Deployment skipped.")

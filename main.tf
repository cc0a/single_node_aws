terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --------------------
# Auto-detect your public IP (optional)
# --------------------
data "external" "myip" {
  program = ["bash", "${path.module}/get-ip.sh"]
}

# --------------------
# Variables
# --------------------
variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

# --------------------
# Networking
# --------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vps-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "vps-public-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --------------------
# Security Group
# --------------------
resource "aws_security_group" "vps_sg" {
  name        = "vps-sg"
  description = "SSH and NoMachine access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4000
    to_port     = 4000
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

# --------------------
# SSH Key Pair
# --------------------
resource "aws_key_pair" "vps_key" {
  key_name   = "vps-key"
  public_key = file(var.ssh_public_key_path)
}

# --------------------
# Ubuntu 24.04 AMI
# --------------------
data "aws_ssm_parameter" "ubuntu_2404" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# --------------------
# EC2 Ubuntu Desktop + NoMachine
# --------------------

resource "aws_instance" "ubuntu_vps" {
  ami           = data.aws_ssm_parameter.ubuntu_2404.value
  instance_type = "m5.large"

  subnet_id                   = aws_subnet.public.id
  key_name                    = aws_key_pair.vps_key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vps_sg.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  # USER DATA SCRIPT
  user_data = <<EOF
#!/bin/bash
set -xe
exec > >(tee -a /var/log/user-data.log) 2>&1

echo "===== Starting EC2 setup ====="

export DEBIAN_FRONTEND=noninteractive

# Wait for apt locks
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  sleep 5
done

echo "Updating system..."
apt-get update -y && apt-get upgrade -y

echo "Installing Ubuntu minimal desktop..."
apt-get install -y ubuntu-desktop-minimal gnome-shell wget

echo "Downloading NoMachine..."
wget --no-check-certificate -O /tmp/nomachine.deb \
  https://web9001.nomachine.com/download/9.2/Linux/nomachine_9.2.18_3_amd64.deb

echo "Installing NoMachine..."
dpkg -i /tmp/nomachine.deb || apt-get install -f -y

echo "Enabling NoMachine service..."
systemctl enable nxserver.service || true
systemctl start nxserver.service || true

echo "Setting ubuntu password..."
echo "ubuntu:<your_password_here>" | chpasswd

echo "Allowing firewall..."
ufw allow 4000/tcp || true

# Install Mullvad (coming soon)

# Configure SSH (coming soon)

# Fail2Ban Install + Setup (coming soon)

# Install OnionShare (coming soon)

echo "READY" > /var/local/desktop-ready
echo "===== Setup complete ====="
EOF

  tags = { Name = "ubuntu-nomachine-desktop" }

  # WAIT FOR INSTANCE TO BE READY
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for Desktop + NoMachine to finish initialization...'",
      "while [ ! -f /var/local/desktop-ready ]; do echo 'Still installing...'; sleep 10; done",
      "echo 'Desktop + NoMachine are READY!'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}

# --------------------
# Outputs
# --------------------
output "public_ip" {
  description = "Public IP"
  value       = aws_instance.ubuntu_vps.public_ip
}

output "nomachine_connection" {
  value = "Connect using: nx://${aws_instance.ubuntu_vps.public_ip}"
}

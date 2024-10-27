# Define a prefix for resource names
variable "proj_prefix" {}

# Fetch availability zones
data "aws_availability_zones" "available" {}

# VPC resource
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.proj_prefix}-k8s-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.proj_prefix}-k8s-igw"
  }
}

# Public Route Table for Internet Access
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.proj_prefix}-k8s-public-rt"
  }
}

# Associate the route table with each subnet
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create 3 subnets within the VPC, one in each availability zone
resource "aws_subnet" "subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.proj_prefix}-k8s-subnet-${count.index + 1}"
  }
}

# Security group allowing SSH access for Kubernetes nodes
resource "aws_security_group" "k8s_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.proj_prefix}-k8s-sg"
  }
}


# EC2 instances to serve as Kubernetes nodes
resource "aws_instance" "k8s_node" {
  count               = 3  # Create 3 instances for Kubernetes cluster nodes
  ami                 = "ami-02db68a01488594c5"  # Amazon Linux 2023 AMI
  instance_type       = "t3.medium"  # EC2 instance type
  subnet_id           = aws_subnet.subnet[count.index].id  # Associate instance with one of the subnets
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]  # Attach the SSH security group
  key_name            = "playground-tf-key"  # Define the key to access nodes

  # User data script to install Docker and Kubernetes tools on each instance
  user_data = <<-EOF
    #!/bin/bash
    # Update package information and install Docker
    yum update -y
    yum install -y docker

    # Start Docker service
    systemctl enable docker
    systemctl start docker

    # Add Kubernetes repository and install kubelet, kubeadm, kubectl
    cat <<EOF2 > /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
    enabled=1
    gpgcheck=1
    repo_gpgcheck=1
    gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
    EOF2

    # Install Kubernetes tools
    yum install -y kubelet kubeadm kubectl

    # Enable and start kubelet service
    systemctl enable kubelet
    systemctl start kubelet
    EOF

  # Tag each instance with a unique name for easier identification
  tags = {
    Name = "${var.proj_prefix}-k8s-node-${count.index + 1}"
  }
}
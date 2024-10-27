# Local variable to define a prefix for resource names
locals {
  proj_prefix = "playground"
}

# AWS provider configuration
provider "aws" {
  region = "eu-north-1"  # AWS region where resources will be created
}

# Configure Terraform backend to store state in an S3 bucket
terraform {
  backend "s3" {
    bucket = "playground.tf.bucket"  # S3 bucket to store Terraform state
    key    = "path/to/your/tfstate"  # Path to the state file in the bucket
    region = "eu-north-1"            # Region for the S3 bucket
  }
}

module "playground-k8s" {
  source = "./modules/k8s"
  proj_prefix = local.proj_prefix
}
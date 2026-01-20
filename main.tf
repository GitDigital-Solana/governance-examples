governance-examples/configurations/terraform/main.tf

```hcl
# Terraform configuration for governance platform

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# S3 bucket for policy storage
resource "aws_s3_bucket" "policy_registry" {
  bucket = "governance-policy-registry-${random_id.suffix.hex}"
  
  tags = {
    Name        = "Policy Registry"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "policy_registry" {
  bucket = aws_s3_bucket.policy_registry.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "policy_registry" {
  bucket = aws_s3_bucket.policy_registry.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB for evaluation results
resource "aws_dynamodb_table" "evaluation_results" {
  name           = "governance-evaluation-results"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "resource_id"
  range_key      = "evaluated_at"

  attribute {
    name = "resource_id"
    type = "S"
  }

  attribute {
    name = "evaluated_at"
    type = "S"
  }

  tags = {
    Name        = "Evaluation Results"
    Environment = "production"
  }
}

# EKS cluster for rules engine
resource "aws_eks_cluster" "governance" {
  name     = "governance-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = module.vpc.private_subnets
  }

  tags = {
    Environment = "production"
  }
}

# IAM role for rules engine
resource "aws_iam_role" "rules_engine" {
  name = "governance-rules-engine-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Service = "governance"
  }
}

resource "aws_iam_role_policy_attachment" "rules_engine_policy" {
  role       = aws_iam_role.rules_engine.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# CloudWatch for logging
resource "aws_cloudwatch_log_group" "governance" {
  name              = "/aws/governance"
  retention_in_days = 365

  tags = {
    Environment = "production"
  }
}

# Random suffix for unique names
resource "random_id" "suffix" {
  byte_length = 4
}

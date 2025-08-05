terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.7.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "6.46.0"
    }
  }

  backend "s3" {
    bucket = "infra-bucket-jammy"
    key    = "test-aws-gpc-iam-auth-hello-world.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Environment = "dev"
      Owner       = "Jakub Jantosik"
      Project     = local.service_name
    }
  }
}

provider "google" {
  project = "test-aws-iam-auth"
  region  = "europe-north1"
}

data "aws_region" "current" {}

locals {
  service_name    = "test-aws-gpc-iam-auth-hello-world"
  resource_prefix = "test-aws-gpc-iam"

  aws_region = data.aws_region.current.region

  artifact_path = "${path.root}/functions/hello-world/dist/index.zip"

  audience = "test"
}

# GCP

resource "google_service_account" "account" {
  account_id   = local.resource_prefix
  display_name = "Service Account"
}

resource "random_id" "main" {
  byte_length = 8
}

resource "google_storage_bucket" "main" {
  name                        = "${local.resource_prefix}-${random_id.main.hex}-gcf-source" # Every bucket name must be globally unique
  location                    = "EU"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "object" {
  name   = "${filesha256(local.artifact_path)}.zip"
  bucket = google_storage_bucket.main.name
  source = local.artifact_path
}

resource "google_cloudfunctions2_function" "main" {
  name     = "${local.resource_prefix}-function"
  location = "europe-north1"

  build_config {
    runtime     = "nodejs22"
    entry_point = "helloHttp"
    source {
      storage_source {
        bucket = google_storage_bucket.main.name
        object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60

    service_account_email = google_service_account.account.email

    environment_variables = {
      AWS_DEFAULT_REGION = local.aws_region
      AWS_REGION         = local.aws_region
      IAM_ROLE_ARN       = aws_iam_role.gcp_role.arn
      AUDIENCE           = local.audience
    }
  }
}

resource "google_cloud_run_service_iam_member" "member" {
  location = google_cloudfunctions2_function.main.location
  service  = google_cloudfunctions2_function.main.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# AWS

resource "aws_iam_role" "gcp_role" {
  name = "${local.resource_prefix}-gcp-role"

  assume_role_policy = data.aws_iam_policy_document.gcp_role_trust.json
}

data "aws_iam_policy_document" "gcp_role_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["accounts.google.com"]
    }

    # This is the audience (aud) field from the token
    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:oaud"

      values = [local.audience]
    }

    # This is the authorized party (azp) from the token
    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:aud"

      values = [google_service_account.account.unique_id]
    }

    # This is the subject (sub) from the token
    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:sub"

      values = [google_service_account.account.unique_id]
    }
  }
}


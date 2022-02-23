terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.74"
    }
    lacework = {
      source  = "lacework/lacework"
      version = "~> 0.14.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "vpc-project"
    key    = "backend/Two tier architecture.tfstate"
    region = "ap-south-1"
    dynamodb_table = "remote-backend"
  }
}
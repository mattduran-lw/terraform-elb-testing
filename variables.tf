variable "key_name" {
  description = "Desired name of AWS key pair"
}

variable "bucket_name" {
  description = "Name of S3 bucket where access logs are to be stored"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-west-2"
}

variable "public_key_path" {
  description = "File path to .pem file -- used for ssh-ing into EC2 instance after creation"
}

# Ubuntu Precise 16.04 LTS (x64)
variable "aws_amis" {
  default = {
    us-east-1 = "ami-f4cc1de2"
    us-east-2 = "ami-fcc19b99"
    us-west-1 = "ami-16efb076"
    us-west-2 = "ami-a58d0dc5"
  }
}

variable "availability_zone" {
  default = "us-west-2a"
}

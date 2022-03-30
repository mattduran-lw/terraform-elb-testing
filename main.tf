
/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@          AWS CONFIGURATION START           @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*/

# Specify the provider and access details
provider "aws" {
  region = var.aws_region
  secret = "blahblahblah"
}

/* 
####### AWS NETWORK RESOURCES #######
*/
# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  availability_zone       = var.availability_zone
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb" {
  name        = "terraform_example_elb"
  description = "Used in the terraform"
  vpc_id      = aws_vpc.default.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "terraform_example"
  description = "Used in the terraform"
  vpc_id      = aws_vpc.default.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/* 
####### ELB RESOURCES #######
*/

# S3 bucket to store Access Logs generated from ELB
# Please note, as of 2/23/22, in order to use the policy attribute
# as shown below, the aws provider version needs to be below v 4.0.
# There is a change in the way that terraform interacts with the 
# S3 resources, see github link for more information.
# https://github.com/hashicorp/terraform-provider-aws/issues/23106
resource "aws_s3_bucket" "elb" {
  bucket = var.bucket_name
  policy = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
    {
    "Effect": "Allow",
    "Principal": {
    "AWS": "797873946194"
    },
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::${var.bucket_name}/*"
  }
  ]
}
EOF
}

# Create an ELB that listens on port 80, stores logs, and checks
# port 80 on the EC2 instance for health checks
resource "aws_elb" "web" {
  name = "terraform-example-elb"

  subnets         = ["${aws_subnet.default.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.web.id}"]

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  access_logs {
    bucket        = aws_s3_bucket.elb.bucket
    bucket_prefix = "elb"
    interval      = 5
    enabled       = true
  }
}


/* 
####### EC2 RESOURCES #######
*/
# Create a key pair to use for ssh-ing into instance
resource "aws_key_pair" "auth" {
  key_name   = var.key_name
  public_key = var.public_key
}


# Create a linux instance that has nginx installed on it
resource "aws_instance" "web" {
  connection {
    # The default username for our AMI
    user        = "ubuntu"
    type        = "ssh"
    host        = aws_instance.web.public_ip
    private_key = file("FILE NAME HERE")
  }

  availability_zone           = var.availability_zone
  associate_public_ip_address = true
  instance_type               = "t2.nano"

  # Lookup the correct AMI based on the region
  # we specified
  ami = lookup(var.aws_amis, var.aws_region)

  # The name of our SSH keypair we created above.
  key_name = aws_key_pair.auth.id

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.default.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = aws_subnet.default.id

  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start",
    ]
  }
}

/* 
####### ATHENA RESOURCES #######
*/

# Creates configuration in Athena, still needs table to be
# created with create query
resource "aws_athena_database" "elblogs" {
  name   = "elblogs"
  bucket = aws_s3_bucket.elb.bucket
}

/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@          AWS CONFIGURATION END             @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*/

/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@       LACEWORK CONFIGURATION START         @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*/

module "aws_config" {
  source                    = "lacework/config/aws"
  version                   = "~> 0.1"
  lacework_integration_name = "MD-Integration"
}

module "aws_cloudtrail" {
  source  = "lacework/cloudtrail/aws"
  version = "~> 1.0"

  bucket_force_destroy  = true
  use_existing_iam_role = true
  iam_role_name         = module.aws_config.iam_role_name
  iam_role_arn          = module.aws_config.iam_role_arn
  iam_role_external_id  = module.aws_config.external_id
}

/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@       LACEWORK CONFIGURATION END           @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*/

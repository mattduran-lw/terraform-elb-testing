# terraform-elb-testing
This terraform plan can be run to create the following resources in AWS and Lacework:

- An EC2 instance running Nginx
- A Classic Load Balancer (ELB)
- A bucket to store access logs for the ELB
- Security policies for these resources
- A Config and Cloudtrail integration in Lacework

## Prerequisites for running this terraform plan
1) Have the Lacework CLI installed
2) Have either the AWS CLI installed and authenticated or provide credentials
3) A public/private key pair to ssh into the EC2 instance

## Things to note
This plan requires at least version 3.74 of the AWS terraform provider due to the changes around S3 policies in the later versions.

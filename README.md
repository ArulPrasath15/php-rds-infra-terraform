# php-rds-infra-terraform

Resources will be created are
- VPC with 2 public and 2 private subnet
- mysql RDS instance with DB subnet group 
- 2 EC2 instance in the public subnet with lamp_installation user data
- ALB for the EC2 instances

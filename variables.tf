variable "owner" {
  default = "arul"
}
variable "vpc_cidr" {
  default = "16.0.0.0/16"
}

variable "public_subnets_cidr" {
  type    = list(any)
  default = ["16.0.1.0/24", "16.0.11.0/24"]
}

variable "private_subnets_cidr" {
  type    = list(any)
  default = ["16.0.2.0/24", "16.0.22.0/24"]
}

variable "availability_zones" {
  type    = list(any)
  default = ["us-east-1a", "us-east-1b"]
}
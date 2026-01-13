variable "region" {
  type    = string
  default = "eu-west-2"
}

variable "cluster_name" {
  type    = string
  default = "eyad-counter-eks"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "pub_subnet_count" {
  type    = number
  default = 2
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu-west-2a", "eu-west-2b"]
}

variable "env" {
  type    = string
  default = "dev"
}

variable "project" {
  type    = string
  default = "eyad-counter-service-p"
}

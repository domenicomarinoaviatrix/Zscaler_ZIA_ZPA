variable "region_code" {
  type = string
}

# variable "location" {
#   description = "The AWS region"
#   type        = string
# }

variable "controller_public_ip" {
  type = string
}

variable "copilot_public_ip" {
  type = string
}

variable "location" {
  type = string
}

variable "transit_gateway_name" {
  type = string
}

variable "az_support" {
  type  = bool
  default = true
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "zpa_cidr" {
  type        = string
  description = "ZPA CIDR"
}

# variable "aws_provider" {
#   type        = string
#   description = "AWS Provider"
# }
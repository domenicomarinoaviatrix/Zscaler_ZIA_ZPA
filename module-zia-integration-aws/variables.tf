variable "region_code" {
  type = string
}

variable "prgw_public_ip" {
  type = string
}

variable "hagw_public_ip" {
  type = string
}

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

variable "aws_zia_account_number" {
  description = "AWS account number for the ZIA"
  type        = string
}
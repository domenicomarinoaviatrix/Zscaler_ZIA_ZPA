# locals {
#   zpa_cidr_map = {
#     "dewc" = "10.209.241.192/26"
#     "weu"  = "10.209.241.64/26"
#     "us2"  = "10.209.242.64/26"
#     "aue"  = "10.209.245.64/26"
#     "brs"  = "10.209.246.64/26"
#     "jpe"  = "10.209.243.64/26"
#     "zan"  = "10.209.245.192/26"
#     "scus" = "10.209.242.192/26"
#     "ins"  = "10.209.244.192/26"
#     "seas" = "10.209.243.192/26"
#     "uaen" = "10.209.244.64/26"
#   }
# }

variable "region_code" {
  type = string
}

# variable "prgw_public_ip" {
#   type = string
# }

# variable "hagw_public_ip" {
#   type = string
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
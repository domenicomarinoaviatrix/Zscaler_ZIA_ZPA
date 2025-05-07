terraform {
  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = "~> 3.1.0"
    }
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">=3.111.0"
      configuration_aliases = [azurerm.zpa]
    }
  }
  required_version = ">= 1.1.0"
}
terraform {
  required_version = "= 1.11.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.60.0"
    }
  }

  backend "azurerm" {
    use_oidc = true
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

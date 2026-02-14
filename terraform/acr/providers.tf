terraform {
  required_version = "= 1.11.4"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.60.0"
    }
  }

  backend "azurerm" {
    key      = "aks-poc.tfstate"
    use_oidc = true
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
  use_oidc = true
}

provider "azurerm" {
  features {}
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tf-state-rg"
    storage_account_name = "tfstatemehdi"
    container_name       = "tfstate"
    key                  = "ollama-project.tfstate"
  }
}
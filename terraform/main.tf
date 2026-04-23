resource "azurerm_resource_group" "main" {
  name     = "ollama-rg"
  location = var.location
}

module "network" {
  source              = "./modules/network"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}

module "security" {
  source              = "./modules/security"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}

module "compute" {
  source              = "./modules/compute"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location

  subnet_id = module.network.app_subnet_id
}

module "monitoring" {
  source              = "./modules/monitoring"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}
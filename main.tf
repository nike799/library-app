# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.59.0"
    }
  }
}
# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}
# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "nikolaygrozdanov-library-${random_integer.ri.result}"
  location = "West Europe"
}

resource "random_integer" "ri" {
  max = 100
  min = 0
}

resource "azurerm_app_service_plan" "sp" {
  name                = "nikolaygrozdanov-library-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"
  reserved = true
  sku {
    tier = "Basic"
    size = "S1"
  }
}

resource "azurerm_mssql_server" "nikolaygrozdanovmssqlserver" {
  name                         = "nikolaygrozdanovmssqlserver"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "missadministrator"
  administrator_login_password = "thisIsKat11"
}

resource "azurerm_mssql_database" "nikolaygrozdanov-mssql-db" {
  name           = "nikolaygrozdanov-mssql-db"
  server_id      = azurerm_mssql_server.nikolaygrozdanovmssqlserver
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  sku_name       = "S0"
  zone_redundant = false
}

resource "azurerm_linux_web_app" "appservice" {
  name                = "nikolaygrozdanov-library-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_app_service_plan.sp.location
  service_plan_id     = azurerm_app_service_plan.sp.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.mssqlservernike.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.nikolaygrozdanov-mssql-db.name};User ID=${azurerm_mssql_server.nikolaygrozdanovmssqlserver.administrator_login};Password=${azurerm_mssql_server.nikolaygrozdanovmssqlserver.administrator_login_password};MultipleActiveResultSets=True;"
  }
}

resource "azurerm_app_service_source_control" "sourcecontrol" {
  app_id                 = azurerm_linux_web_app.appservice.id
  repo_url               = "https://github.com/nike799/taskboard"
  branch                 = "master"
  use_manual_integration = true
}

resource "azurerm_mssql_firewall_rule" "mssqlfirewall" {
  name             = "FirewallRule1"
  server_id        = azurerm_mssql_server.mssqlservernike.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

output "webapp_url" {
  value = azurerm_linux_web_app.appservice.default_hostname
}

output "webapp_ips" {
  value = azurerm_linux_web_app.appservice.outbound_ip_addresses
}

## Data source to retrieve the Azure route table
## Route table with quad-zero pointing to Load Balancer
data "azurerm_route_table" "zscaler_route_table" {
  provider            = azurerm.zia
  name                = "rt-cc-${var.region_code}-prd"
  resource_group_name = "rg-CC-MCB-${upper(var.region_code)}-PRD" ## try small caps
}



resource "azurerm_route" "spkgw_to_trgw_pr" {
  provider            = azurerm.zia
  name                = "spkgw-to-trgw-pr"
  resource_group_name = data.azurerm_route_table.zscaler_route_table.resource_group_name
  route_table_name    = data.azurerm_route_table.zscaler_route_table.name
  address_prefix      = "${var.prgw_public_ip}/32"
  next_hop_type       = "Internet"
}



resource "azurerm_route" "spkgw_to_trgw_ha" {
  provider            = azurerm.zia
  name                = "spkgw-to-trgw-ha"
  resource_group_name = data.azurerm_route_table.zscaler_route_table.resource_group_name
  route_table_name    = data.azurerm_route_table.zscaler_route_table.name
  address_prefix      = "${var.hagw_public_ip}/32"
  next_hop_type       = "Internet"
}


resource "azurerm_route" "spkgw_to_controller" {
  provider            = azurerm.zia
  name                = "spkgw-to-controller"
  resource_group_name = data.azurerm_route_table.zscaler_route_table.resource_group_name
  route_table_name    = data.azurerm_route_table.zscaler_route_table.name
  address_prefix      = "${var.controller_public_ip}/32"
  next_hop_type       = "Internet"
}


resource "azurerm_route" "spkgw-to-copilot" {
  provider            = azurerm.zia
  name                = "spkgw-to-copilot"
  resource_group_name = data.azurerm_route_table.zscaler_route_table.resource_group_name
  route_table_name    = data.azurerm_route_table.zscaler_route_table.name
  address_prefix      = "${var.copilot_public_ip}/32"
  next_hop_type       = "Internet"
}


data "azurerm_virtual_network" "zia_vnet" {
  provider            = azurerm.zia
  name                = "vn-cc-mcb-${var.region_code}-prd"
  resource_group_name = data.azurerm_route_table.zscaler_route_table.resource_group_name
}

data "azurerm_subnet" "zia_subnet" {
  provider             = azurerm.zia
  name                 = "sn-avx-${var.region_code}-prd"
  resource_group_name  = data.azurerm_route_table.zscaler_route_table.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.zia_vnet.name
}

module "azr-spk-zia" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.9"

  cloud                            = "Azure"
  name                             = "azr-${var.region_code}-spk-zia-01"
  gw_name                          = "azr-${var.region_code}-spk-zia-01"
  region                           = var.location
  account                          = "AZR-NN-ZCC_MCB_ZIA-PRD"
  instance_size                    = "Standard_D2_v5"
  transit_gw                       = var.transit_gateway_name
  use_existing_vpc                 = true
  az_support                       = var.az_support
  vpc_id                           = format("%s:%s:%s", data.azurerm_virtual_network.zia_vnet.name, data.azurerm_virtual_network.zia_vnet.resource_group_name, data.azurerm_virtual_network.zia_vnet.guid)
  gw_subnet                        = data.azurerm_subnet.zia_subnet.address_prefix
  ha_gw                            = false
  attached                         = false
  included_advertised_spoke_routes = "0.0.0.0/0"
}


resource "aviatrix_segmentation_network_domain_association" "zia_shared_services" {
  network_domain_name = "SHARED_SERVICES"
  attachment_name     = module.azr-spk-zia.spoke_gateway.gw_name
}

resource "azurerm_subnet_route_table_association" "zia_sn_rt_association" {
  provider       = azurerm.zia
  subnet_id      = data.azurerm_subnet.zia_subnet.id
  route_table_id = data.azurerm_route_table.zscaler_route_table.id

  depends_on = [ module.azr-spk-zia ]
}

resource "aviatrix_spoke_transit_attachment" "this" {
  spoke_gw_name   = module.azr-spk-zia.spoke_gateway.gw_name
  transit_gw_name = var.transit_gateway_name

  depends_on = [ azurerm_subnet_route_table_association.zia_sn_rt_association ]
}
output "zia_gw_subnet" { value = data.azurerm_subnet.zia_subnet.address_prefix }

# output "zia_subnet_id" { value = data.azurerm_subnet.zia_subnet.id }
# output "zia_route_table_id" { value = data.azurerm_route_table.zscaler_route_table.id }

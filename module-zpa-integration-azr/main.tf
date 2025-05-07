resource "azurerm_resource_group" "zpa_rg" {
  provider            = azurerm.zpa
  name                = "rg-zpa-${var.region_code}-mcb-${var.environment}"
  location            = var.location
}

resource "azurerm_virtual_network" "zpa_vnet" {
  provider            = azurerm.zpa
  name                = "vn-azr-${var.region_code}-zpa-mcb-${var.environment}"
  address_space       = [var.zpa_cidr]
  location            = var.location
  resource_group_name = azurerm_resource_group.zpa_rg.name
}

# ZPA Subnets
resource "azurerm_subnet" "zpa_subnet" {
  provider             = azurerm.zpa
  count                = 2
  name                 = "sn-azr-az${count.index + 1}-${var.region_code}-zpa-mcb-${var.environment}"
  resource_group_name  = azurerm_resource_group.zpa_rg.name
  virtual_network_name = azurerm_virtual_network.zpa_vnet.name
  address_prefixes     = [cidrsubnet(element(azurerm_virtual_network.zpa_vnet.address_space, 0), 2, count.index)]
}

# AVX Subnet
resource "azurerm_subnet" "zpa_avx_subnet" {
  provider            = azurerm.zpa
  name                 = "sn-azr-avx-${var.region_code}-zpa-mcb-${var.environment}"
  resource_group_name  = azurerm_resource_group.zpa_rg.name
  virtual_network_name = azurerm_virtual_network.zpa_vnet.name
  address_prefixes     = [cidrsubnet(element(azurerm_virtual_network.zpa_vnet.address_space, 0), 2, 2)]
}


#Public IP Prefix creation 
resource "azurerm_public_ip_prefix" "zpa_pip_prefixes_az" {
  provider            = azurerm.zpa
  count               = var.az_support ? 2 : 0
  name                = "pip-az${count.index + 1}-${var.region_code}-zpa-mcb-${var.environment}"
  resource_group_name = azurerm_resource_group.zpa_rg.name
  location            = azurerm_resource_group.zpa_rg.location
  prefix_length       = 28
  zones               = ["${count.index + 1}"] 
}

resource "azurerm_public_ip_prefix" "zpa_pip_prefixes_no_az" {
  provider            = azurerm.zpa
  count               = var.az_support ? 0 : 2
  name                = "pip-az${count.index + 1}-${var.region_code}-zpa-mcb-${var.environment}"
  resource_group_name = azurerm_resource_group.zpa_rg.name
  location            = azurerm_resource_group.zpa_rg.location
  prefix_length       = 28 
}


#Create NAT gw with Public IP pre-fix

resource "azurerm_nat_gateway" "zpa_nat_gw" {
  provider            = azurerm.zpa
  count               = 2
  name                = "nat-gw-az${count.index + 1}-${var.region_code}-zpa-mcb-${var.environment}"
  location            = azurerm_resource_group.zpa_rg.location
  resource_group_name = azurerm_resource_group.zpa_rg.name
  sku_name            = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "zpa_ass_az" {
  provider            = azurerm.zpa
  count               = var.az_support ? 2 : 0
  nat_gateway_id      = azurerm_nat_gateway.zpa_nat_gw[count.index].id
  public_ip_prefix_id = azurerm_public_ip_prefix.zpa_pip_prefixes_az[count.index].id
}

resource "azurerm_nat_gateway_public_ip_prefix_association" "zpa_ass_no_az" {
  provider            = azurerm.zpa
  count               = var.az_support ? 0 : 2
  nat_gateway_id      = azurerm_nat_gateway.zpa_nat_gw[count.index].id
  public_ip_prefix_id = azurerm_public_ip_prefix.zpa_pip_prefixes_no_az[count.index].id
}


#Attach NAT-gateway to Subnet

resource "azurerm_subnet_nat_gateway_association" "zpa_sn_gw_ass" {
  provider            = azurerm.zpa
  count               = 2
  subnet_id           = azurerm_subnet.zpa_subnet[count.index].id
  nat_gateway_id      = azurerm_nat_gateway.zpa_nat_gw[count.index].id
}



######### NSG ############
resource "azurerm_network_security_group" "zpa_nsg" {
  provider            = azurerm.zpa
  name                = "nsg-${var.region_code}-zpa-mcb-${var.environment}"
  location            = azurerm_resource_group.zpa_rg.location
  resource_group_name = azurerm_resource_group.zpa_rg.name
}

resource "azurerm_network_security_rule" "zpa_NNDefaultDenyInBoundAllFromCORP" {
  provider                    = azurerm.zpa
  name                        = "NNDefaultDenyInBoundAllFromCORP-${var.region_code}-zpa-mcb-${var.environment}"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12"]
  destination_address_prefix = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.zpa_rg.name
  network_security_group_name = azurerm_network_security_group.zpa_nsg.name
}

resource "azurerm_network_security_rule" "zpa_NNDefaultAllowInBoundRDPFromCORP" {
  provider                    = azurerm.zpa
  name                        = "NNDefaultAllowInBoundRDPFromCORP-${var.region_code}-zpa-mcb-${var.environment}"
  priority                    = 4095
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12"]
  destination_address_prefix = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.zpa_rg.name
  network_security_group_name = azurerm_network_security_group.zpa_nsg.name
}

resource "azurerm_network_security_rule" "zpa_NNDefaultAllowInBoundSSHFromCORP" {
  provider                    = azurerm.zpa
  name                        = "NNDefaultAllowInBoundSSHFromCORP-${var.region_code}-zpa-mcb-${var.environment}"
  priority                    = 4094
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12"]
  destination_address_prefix = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.zpa_rg.name
  network_security_group_name = azurerm_network_security_group.zpa_nsg.name
}

resource "azurerm_network_security_rule" "zpa_NNDefaultAllowInBoundIcmpFromCORP" {
  provider                    = azurerm.zpa
  name                        = "NNDefaultAllowInBoundIcmpFromCORP-${var.region_code}-zpa-mcb-${var.environment}"
  priority                    = 4093
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.0.0.0/8", "172.16.0.0/12"]
  destination_address_prefix = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.zpa_rg.name
  network_security_group_name = azurerm_network_security_group.zpa_nsg.name
}

resource "azurerm_network_security_rule" "zpa_NNAllowInBoundGSOScanningTool" {
  provider                    = azurerm.zpa
  name                        = "NNAllowInBoundGSOScanningTool-${var.region_code}-zpa-mcb-${var.environment}"
  priority                    = 4092
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = ["10.1.80.56", "10.1.80.58"]
  destination_address_prefix = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.zpa_rg.name
  network_security_group_name = azurerm_network_security_group.zpa_nsg.name
}

resource "azurerm_network_security_rule" "zpa_NNAllowInBoundPIM" {
  provider                    = azurerm.zpa
  name                        = "NNAllowInBoundPIM-${var.region_code}-zpa-mcb-${var.environment}"
  priority                    = 4091
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "445"
  source_address_prefixes     = ["10.1.141.1", "10.1.141.2"]
  destination_address_prefix = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.zpa_rg.name
  network_security_group_name = azurerm_network_security_group.zpa_nsg.name
}


resource "azurerm_subnet_network_security_group_association" "zpa_nsg2subnet" {
  provider                  = azurerm.zpa
  count                     = 2
  subnet_id                 = azurerm_subnet.zpa_subnet[count.index].id
  network_security_group_id = azurerm_network_security_group.zpa_nsg.id
}

############## AVX Routing ############################################
resource "azurerm_route_table" "zpa_avx_route_table" {
  provider            = azurerm.zpa
  name                = "rt-${var.region_code}-zpa-avx-mcb-${var.environment}"
  resource_group_name = azurerm_resource_group.zpa_rg.name
  location            = azurerm_resource_group.zpa_rg.location
}

resource "azurerm_route" "zpa_spkgw_default" {
  provider            = azurerm.zpa
  name                = "rt-${var.region_code}-spkgw-to-internet-${var.environment}"
  resource_group_name = azurerm_resource_group.zpa_rg.name
  route_table_name    = azurerm_route_table.zpa_avx_route_table.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "zpa_sn_rt_avx_association" {
  provider                  = azurerm.zpa
  subnet_id                 = azurerm_subnet.zpa_avx_subnet.id
  route_table_id            = azurerm_route_table.zpa_avx_route_table.id
}


############## ZPA Routing ############################################
resource "azurerm_route_table" "zpa_connector_route_table" {
  provider            = azurerm.zpa
  name                = "rt-${var.region_code}-zpa-mcb-${var.environment}"
  resource_group_name = azurerm_resource_group.zpa_rg.name
  location            = azurerm_resource_group.zpa_rg.location
}

resource "azurerm_route" "zpa_default" {
  provider            = azurerm.zpa
  name                = "rt-${var.region_code}-default-${var.environment}"
  resource_group_name = azurerm_resource_group.zpa_rg.name
  route_table_name    = azurerm_route_table.zpa_connector_route_table.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "zpa_sn_rt_association" {
  provider                  = azurerm.zpa
  count                     = 2
  subnet_id                 = azurerm_subnet.zpa_subnet[count.index].id
  route_table_id            = azurerm_route_table.zpa_connector_route_table.id
}


##### AVX Spokes########################################
module "azr-spk-zpa" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.9"
  depends_on = [ azurerm_subnet_route_table_association.zpa_sn_rt_association ]
  cloud                            = "Azure"
  name                             = "azr-${var.region_code}-spk-zpa-01"
  gw_name                          = "azr-${var.region_code}-spk-zpa-01"
  region                           = var.location
  account                          = "AZR-NN-ZCC_MCB_ZPA-PRD"
  instance_size                    = "Standard_D2_v5"
  transit_gw                       = var.transit_gateway_name
  use_existing_vpc                 = true
  az_support                       = var.az_support
  vpc_id                           = format("%s:%s:%s", azurerm_virtual_network.zpa_vnet.name, azurerm_resource_group.zpa_rg.name, azurerm_virtual_network.zpa_vnet.guid)
  gw_subnet                        = azurerm_subnet.zpa_avx_subnet.address_prefixes[0]
  ha_gw                            = false
  attached                         = false
}



resource "aviatrix_spoke_transit_attachment" "zpa_avx_attachment" {
  spoke_gw_name   = module.azr-spk-zpa.spoke_gateway.gw_name
  transit_gw_name = var.transit_gateway_name

  depends_on = [ azurerm_subnet_route_table_association.zpa_sn_rt_association ]
}

resource "aviatrix_segmentation_network_domain_association" "zpa_shared_services" {
  network_domain_name = "SHARED_SERVICES"
  attachment_name     = module.azr-spk-zpa.spoke_gateway.gw_name
}
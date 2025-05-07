#  provider "aws" {
#   alias  = "zpa_euc1"
#   region = var.location
# }

data "aws_availability_zones" "available" {}

resource "aws_vpc" "zpa_vpc" {
  #provider             = aws.zpa_euc1
  cidr_block           = var.zpa_cidr
  enable_dns_support   = true 
  enable_dns_hostnames = true 
  
  tags = {
    Name = "vpc-aws-${var.region_code}-zpa-mcb-${var.environment}"
  }
}

resource "aws_internet_gateway" "zpa_igw" {
  vpc_id = aws_vpc.zpa_vpc.id
  
  tags = {
    Name = "igw-aws-${var.region_code}-zpa-mcb-${var.environment}"
  }
}


# ZPA Subnets
resource "aws_subnet" "zpa_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.zpa_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.zpa_vpc.cidr_block, 2, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  
  tags = {
    Name = "sn-aws-az${count.index + 1}-${var.region_code}-zpa-mcb-${var.environment}"
  }
}

# AVX Subnet
resource "aws_subnet" "zpa_avx_subnet" {
  vpc_id            = aws_vpc.zpa_vpc.id  
  cidr_block        = cidrsubnet(aws_vpc.zpa_vpc.cidr_block, 2, 2) 
  availability_zone = data.aws_availability_zones.available.names[0] 
  
  tags = {
    Name = "sn-aws-avx-${var.region_code}-zpa-mcb-${var.environment}"
  }
}


# #Public IP Prefix creation 
resource "aws_eip" "zpa_eip" {
  count = 2
  domain                      = "vpc" 
  tags = {
    Name = "eip-aws${count.index + 1}-${var.region_code}-zpa-mcb-${var.environment}"
  }
}


# Create NAT gw with Public IP pre-fix

resource "aws_nat_gateway" "zpa_nat_gw" {
  count         = 2
  allocation_id = aws_eip.zpa_eip[count.index].id
  subnet_id     = aws_subnet.zpa_subnet[count.index].id
  tags = {
    Name = "nat-gw-aws${count.index + 1}-${var.region_code}-zpa-mcb-${var.environment}"
  }
}

# ######### NSG ############

resource "aws_security_group" "zpa_nsg" {
  name        = "nsg-${var.region_code}-zpa-mcb-${var.environment}"
  description = "NSG for ${var.region_code}-zpa-mcb-${var.environment}"
  vpc_id      = aws_vpc.zpa_vpc.id

  tags = {
    Name = "nsg-${var.region_code}-zpa-mcb-${var.environment}"
  }
}

resource "aws_security_group_rule" "zpa_NNDefaultAllowInBoundRDPFromCORP" {
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8", "172.16.0.0/12"]
  security_group_id = aws_security_group.zpa_nsg.id

  description = "Allow inbound RDP from CORP IP ranges"
}

resource "aws_security_group_rule" "zpa_NNDefaultAllowInBoundSSHFromCORP" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8", "172.16.0.0/12"]
  security_group_id = aws_security_group.zpa_nsg.id
  description       = "Allow inbound SSH from CORP IP ranges"
}

resource "aws_security_group_rule" "zpa_NNDefaultAllowInBoundIcmpFromCORP" {
  type                     = "ingress"
  from_port                = -1 # ICMP type, -1 represents all types
  to_port                  = -1 # ICMP code, -1 represents all codes
  protocol                 = "icmp"
  cidr_blocks              = ["10.0.0.0/8", "172.16.0.0/12"]
  security_group_id        = aws_security_group.zpa_nsg.id
  description              = "Allow inbound ICMP from CORP IP ranges"
}

resource "aws_security_group_rule" "zpa_NNAllowInBoundGSOScanningTool" {
  type                     = "ingress"
  from_port                = 0  # Allows all ports
  to_port                  = 65535  # Allows all ports
  protocol                 = "tcp"
  cidr_blocks              = ["10.1.80.56/32", "10.1.80.58/32"]
  security_group_id        = aws_security_group.zpa_nsg.id
  description              = "Allow inbound TCP from specific IPs for GSO Scanning Tool"
}

resource "aws_security_group_rule" "zpa_NNAllowInBoundPIM" {
  type                     = "ingress"
  from_port                = 445
  to_port                  = 445
  protocol                 = "tcp"
  cidr_blocks              = ["10.1.141.1/32", "10.1.141.2/32"]
  security_group_id        = aws_security_group.zpa_nsg.id
  description              = "Allow inbound TCP on port 445 from specific IPs for PIM"
}


# ############## AVX Routing ############################################

resource "aws_route_table" "zpa_avx_route_table" {
  vpc_id = aws_vpc.zpa_vpc.id  
  tags = {
    Name = "rt-${var.region_code}-zpa-avx-mcb-${var.environment}"
  }
}


resource "aws_route" "zpa_spkgw_default" {
  route_table_id         = aws_route_table.zpa_avx_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.zpa_igw.id 
}

resource "aws_route_table_association" "zpa_sn_rt_avx_association" {
  subnet_id      = aws_subnet.zpa_avx_subnet.id
  route_table_id = aws_route_table.zpa_avx_route_table.id
}

# ############## ZPA Routing ############################################
resource "aws_route_table" "zpa_connector_route_table" {
  vpc_id = aws_vpc.zpa_vpc.id

  tags = {
    Name = "rt-${var.region_code}-zpa-mcb-${var.environment}"
  }
}

resource "aws_route" "zpa_default" {
  route_table_id         = aws_route_table.zpa_connector_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.zpa_igw.id
}

resource "aws_route_table_association" "zpa_sn_rt_association" {
  count          = 2
  subnet_id      = aws_subnet.zpa_subnet[count.index].id
  route_table_id = aws_route_table.zpa_connector_route_table.id
}


##### AVX Spokes#######################################
module "aws-spk-zpa" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.9"
  depends_on = [ aws_route_table_association.zpa_sn_rt_avx_association ]
  cloud                            = "AWS"
  name                             = "aws-${var.region_code}-spk-zpa-01"
  gw_name                          = "aws-${var.region_code}-spk-zpa-01"
  region                           = var.location
  account                          = "AWS-NET-ZCC_MCB_ZPA-PRD"
  instance_size                    = "c5n.xlarge"
  transit_gw                       = var.transit_gateway_name
  use_existing_vpc                 = true
  az_support                       = var.az_support
  #vpc_id                           = format("%s:%s:%s", aws_vpc.zpa_vpc.name, azurerm_resource_group.zpa_rg.name, azurerm_virtual_network.zpa_vnet.guid)
  vpc_id                           = aws_vpc.zpa_vpc.id
  gw_subnet                        = aws_subnet.zpa_avx_subnet.cidr_block
  ha_gw                            = false
  attached                         = false
}



resource "aviatrix_spoke_transit_attachment" "zpa_aws_avx_attachment" {
  spoke_gw_name   = module.aws-spk-zpa.spoke_gateway.gw_name
  transit_gw_name = var.transit_gateway_name

  depends_on = [ module.aws-spk-zpa ]
}

resource "aviatrix_segmentation_network_domain_association" "zpa_aws_shared_services" {
  network_domain_name = "SHARED_SERVICES"
  attachment_name     = module.aws-spk-zpa.spoke_gateway.gw_name
}
# Fetch the VPC Route Table based on a known tag, or adjust according to your setup
data "aws_vpc" "zia-vpc" {
  provider = aws.zia  
  tags = {
    Name = "AWS-NET-${var.aws_zia_account_number}-PRD-${lower(var.location)}-VPC" 
  }
}

#####testing
data "aws_route_table" "zscaler_route_table" {
  provider = aws.zia  
  vpc_id = data.aws_vpc.zia-vpc.id

  tags = {
    Name = "AWS-NET-${var.aws_zia_account_number}-PRD-${lower(var.location)}-Tier1-rt"
  }
}
#####testing

data "aws_route_table" "zscaler_route_table_a" {
  provider = aws.zia  
  vpc_id = data.aws_vpc.zia-vpc.id

  tags = {
    Name = "AWS-NET-${var.aws_zia_account_number}-PRD-${lower(var.location)}-Tier1-1a-rt"
  }
}

data "aws_route_table" "zscaler_route_table_b" {
  provider = aws.zia  
  vpc_id = data.aws_vpc.zia-vpc.id

  tags = {
    Name = "AWS-NET-${var.aws_zia_account_number}-PRD-${lower(var.location)}-Tier1-1b-rt"
  }
}

data "aws_internet_gateway" "existing_gw" {
  provider = aws.zia  
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.zia-vpc.id]
  }
}

data "aws_subnet" "zia_subnet_a" {
  provider = aws.zia  
  filter {
    name   = "tag:Name"
    values = ["AWS-NET-${var.aws_zia_account_number}-PRD-${lower(var.location)}-Tier1-public-1a"]
  }

  vpc_id = data.aws_vpc.zia-vpc.id

}

data "aws_subnet" "zia_subnet_b" {
  provider = aws.zia  
  filter {
    name   = "tag:Name"
    values = ["AWS-NET-${var.aws_zia_account_number}-PRD-${lower(var.location)}-Tier1-public-1b"]
  }

  vpc_id = data.aws_vpc.zia-vpc.id

}

module "aws-spk-zia" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.6.9"

  cloud                            = "AWS"
  name                             = "aws-${var.region_code}-spk-zia-01"
  gw_name                          = "aws-${var.region_code}-spk-zia-01"
  region                           = var.location
  account                          = "AWS-NET-ZCC_MCB_ZIA-PRD"
  instance_size                    = "c5n.xlarge"
  transit_gw                       = var.transit_gateway_name
  use_existing_vpc                 = true
  az_support                       = var.az_support
  vpc_id                           = data.aws_vpc.zia-vpc.id
  gw_subnet                        = data.aws_subnet.zia_subnet_a.cidr_block 
  hagw_subnet                      = data.aws_subnet.zia_subnet_b.cidr_block 
  ha_gw                            = true 
  attached                         = false
  included_advertised_spoke_routes = "0.0.0.0/0"
}



#################################################
# Adding public TRGW IP address to RT "a" and "b"
#################################################
resource "aws_route" "spkgw_to_trgw_pr_a" {
  provider = aws.zia  
  route_table_id         = data.aws_route_table.zscaler_route_table_a.id
  destination_cidr_block = "${var.prgw_public_ip}/32"
  gateway_id             = data.aws_internet_gateway.existing_gw.id  
}

resource "aws_route" "spkgw_to_trgw_pr_a_ha" {
  provider = aws.zia  
  route_table_id         = data.aws_route_table.zscaler_route_table_a.id
  destination_cidr_block = "${var.hagw_public_ip}/32"
  gateway_id             = data.aws_internet_gateway.existing_gw.id  
}

resource "aws_route" "spkgw_to_trgw_pr_b" {
  provider = aws.zia  
  route_table_id         = data.aws_route_table.zscaler_route_table_b.id
  destination_cidr_block = "${var.prgw_public_ip}/32"
  gateway_id             = data.aws_internet_gateway.existing_gw.id  
}

resource "aws_route" "spkgw_to_trgw_pr_b_ha" {
  provider = aws.zia  
  route_table_id         = data.aws_route_table.zscaler_route_table_b.id
  destination_cidr_block = "${var.hagw_public_ip}/32"
  gateway_id             = data.aws_internet_gateway.existing_gw.id  
}

#######################################################
# Adding public Controller IP address to RT "a" and "b"
#######################################################
resource "aws_route" "spkgw_to_controller_pr_a" {
  provider = aws.zia  
  route_table_id         = data.aws_route_table.zscaler_route_table_a.id
  destination_cidr_block = "${var.controller_public_ip}/32"
  gateway_id             = data.aws_internet_gateway.existing_gw.id  
}

resource "aws_route" "spkgw_to_controller_pr_b" {
  provider = aws.zia  
  route_table_id         = data.aws_route_table.zscaler_route_table_b.id
  destination_cidr_block = "${var.controller_public_ip}/32"
  gateway_id             = data.aws_internet_gateway.existing_gw.id  
}

#######################################################
# Adding public Copilot IP address to RT "a" and "b"
########################################################
resource "aws_route" "spkgw_to_copilot_pr_a" {
  provider = aws.zia  
  route_table_id         = data.aws_route_table.zscaler_route_table_a.id
  destination_cidr_block = "${var.copilot_public_ip}/32"
  gateway_id             = data.aws_internet_gateway.existing_gw.id  
}

resource "aws_route" "spkgw_to_copilot_pr_b" {
  provider = aws.zia  
  route_table_id         = data.aws_route_table.zscaler_route_table_b.id
  destination_cidr_block = "${var.copilot_public_ip}/32"
  gateway_id             = data.aws_internet_gateway.existing_gw.id  
}


resource "aviatrix_segmentation_network_domain_association" "aws_zia_egress" {
  network_domain_name = "SHARED_SERVICES"
  attachment_name     = module.aws-spk-zia.spoke_gateway.gw_name
}


resource "aws_route_table_association" "zia_sn_rt_association_a" {
  provider = aws.zia  
  subnet_id      = data.aws_subnet.zia_subnet_a.id
  route_table_id = data.aws_route_table.zscaler_route_table_a.id
}

resource "aws_route_table_association" "zia_sn_rt_association_b" {   
  provider = aws.zia  
  subnet_id      = data.aws_subnet.zia_subnet_b.id
  route_table_id = data.aws_route_table.zscaler_route_table_b.id
}

resource "aviatrix_spoke_transit_attachment" "this" {
  spoke_gw_name   = module.aws-spk-zia.spoke_gateway.gw_name
  transit_gw_name = var.transit_gateway_name

  depends_on = [ aws_route_table_association.zia_sn_rt_association_a, aws_route_table_association.zia_sn_rt_association_b ]
}
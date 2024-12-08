# ================= USERDATA ================
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")
}

# ================= NETWORK =================

module "wordpress_vpc" {
  source = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/vpc"
  name                 = "${var.name}-vpc"
  cidr_block           = var.cidr_block
  private_subnet_cidr  = var.private_subnet_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  network_interface_id = module.wp_bastion_server.primary_network_interface_id



  tags                 = var.tags
}

# ================= SERVERS =================

module "wp_bastion_server" {
  source = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/ec2"
  ami           = var.ami
  instance_type = var.wp_type
  subnet_id     = module.wordpress_vpc.public_subnet_id
  tags = merge(var.tags, {
    "Name" = "Website Bastion"
  })
  key_name               = module.wp_keypair.key_name
  vpc_security_group_ids = [module.wordpress_server_sg.sg_id]
}

module "wordpress_server" {
  source = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/ec2"
  ami           = var.ami
  instance_type = var.wp_type
  subnet_id     = module.wordpress_vpc.private_subnet_id
  tags = merge(var.tags, {
    "Name" = "Kubecounty WP Node"
  })
  key_name               = module.wp_keypair.key_name
  vpc_security_group_ids = [module.wordpress_server_sg.sg_id]

  user_data = data.template_file.user_data.rendered
}

# ================= NAT INSTANCE =================

module "wp-nat" {
  source = "git::https://github.com/RaJiska/terraform-aws-fck-nat.git"

  name      = "wp_nat_instance"
  vpc_id    = module.wordpress_vpc.vpc_id
  subnet_id = module.wordpress_vpc.public_subnet_id
  # ha_mode              = true                 # Enables high-availability mode
  # eip_allocation_ids   = ["eipalloc-abc1234"] # Allocation ID of an existing EIP
  # use_cloudwatch_agent = true                 # Enables Cloudwatch agent and have metrics reported
  instance_type = "t4g.micro"

  update_route_tables = true
  route_tables_ids = {
    "private" = module.wordpress_vpc.private_rt_id
  }
}

# ================= KEYS =================

module "wp_keypair" {
  source   = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/keypair"
  key_name = var.key_name
}

# ================= SECURITY GROUPS =================

module "wordpress_server_sg" {
  source      = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/sg"
  name        = "${var.name}-wp-sg"
  description = var.sg_description
  tags        = var.tags
  vpc_id      = module.wordpress_vpc.vpc_id
  rules = [
    {
      "type"        = "ingress"
      "from_port"   = 22,
      "to_port"     = 22,
      "protocol"    = "tcp",
      "cidr_blocks" = ["10.0.1.0/24"]
    },
    {
      "type"        = "ingress"
      "description" = "HTTP"
      "from_port"   = 80,
      "to_port"     = 80,
      "protocol"    = "tcp",
      "cidr_blocks" = ["10.0.2.0/24"]
    },
    {
      "type"        = "ingress"
      "description" = "HTTS"
      "from_port"   = 443,
      "to_port"     = 443,
      "protocol"    = "tcp",
      "cidr_blocks" = ["10.0.2.0/24"]
    },
    {
      "type"        = "egress"
      "from_port"   = 0,
      "to_port"     = 0,
      "protocol"    = "-1",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
  ]
}


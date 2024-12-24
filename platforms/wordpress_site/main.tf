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

# ============= ROLES AND POLICY ============

data "aws_iam_policy_document" "github_oidc_trust_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.github_oidc.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:MalchielUrias/kc_wp_site:*"]
    }
  }
}

data "aws_iam_policy_document" "ssm_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "github_access_policy" {
  statement {
    effect = "Allow"

    actions = [ 
      "ec2:DescribeInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
      "ssm:SendCommand",
      "ssm:GetCommandInvocation"
     ]

    resources = [ module.wp_server.arn, module.wp_bastion_server.arn, "arn:aws:ssm:eu-west-1::document/AWS-RunShellScript" ]
  }
}

module "github_oidc" {
  source = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/openid_connect"
}

# Create KMS Role
module "github_oidc_role" {
  source = "github.com/MalchielUrias/tepe_masterclass//modules/iam"
  name = "github_oidc_role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust_policy.json
  policy_arns = []
}

# Create KMS Policy 
module "github_oidc_policy" {
  source = "github.com/MalchielUrias/tepe_masterclass//modules/iam-role"
  policy_name = "github_oidc_policy"
  policy_role = module.github_oidc_role.role_name
  policy = data.aws_iam_policy_document.github_access_policy.json
}

# Instance Profile

module "instance_profile" {
  source = "github.com/MalchielUrias/tepe_masterclass//modules/iam"
  name = "instance_profile"
  assume_role_policy = data.aws_iam_policy_document.ssm_role.json
  policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm_instance_profile"
  role = module.instance_profile.role_name
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
  vpc_security_group_ids = [module.wordpress_bastion_sg.sg_id]
  user_data = null
}

module "wp_server" {
  source = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/ec2"
  ami           = var.ami
  instance_type = var.wp_type
  subnet_id     = module.wordpress_vpc.private_subnet_id
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  tags = merge(var.tags, {
    "Name" = "Kubecounty WP Node"
  })
  key_name               = module.wp_keypair.key_name
  vpc_security_group_ids = [module.wordpress_server_sg.sg_id]

  user_data = file("${path.module}/user_data.sh")
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
      "cidr_blocks" = ["10.2.20.0/24"]
    },
    {
      "type"        = "ingress"
      "description" = "HTTP"
      "from_port"   = 80,
      "to_port"     = 80,
      "protocol"    = "tcp",
      "cidr_blocks" = ["10.2.20.0/24"]
    },
    {
      "type"        = "ingress"
      "description" = "HTTS"
      "from_port"   = 443,
      "to_port"     = 443,
      "protocol"    = "tcp",
      "cidr_blocks" = ["10.2.20.0/24"]
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

module "wordpress_bastion_sg" {
  source      = "github.com/MalchielUrias/kubecounty_infrastructure//terraform/aws/modules/sg"
  name        = "${var.name}-wp-bastion-sg"
  description = var.sg_description
  tags        = var.tags
  vpc_id      = module.wordpress_vpc.vpc_id
  rules = [
    {
      "type"        = "ingress"
      "from_port"   = 22,
      "to_port"     = 22,
      "protocol"    = "tcp",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
    {
      "type"        = "ingress"
      "description" = "HTTP"
      "from_port"   = 80,
      "to_port"     = 80,
      "protocol"    = "tcp",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
    {
      "type"        = "ingress"
      "description" = "HTTS"
      "from_port"   = 443,
      "to_port"     = 443,
      "protocol"    = "tcp",
      "cidr_blocks" = ["0.0.0.0/0"]
    },
    {
      "type"        = "egress"
      "from_port"   = 0,
      "to_port"     = 0,
      "protocol"    = "-1",
      "cidr_blocks" = ["0.0.0.0/0"]
    }
  ]
}
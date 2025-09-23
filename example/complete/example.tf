provider "aws" {
  region = "eu-west-1"
}

##-----------------------------------------------------------------------------
## VPC Module Call.
##-----------------------------------------------------------------------------
module "vpc" {
  source     = "git@github.com:opszero/terraform-aws-vpc?ref=v1.0.1"
  name       = "test"
  cidr_block = "10.0.0.0/16"
}

##-----------------------------------------------------------------------------
## Security Group Module Call.
##-----------------------------------------------------------------------------
module "security_group" {
  source = "./../../"
  name   = "aap"
  vpc_id = module.vpc.vpc_id

  ## INGRESS Rules
  new_sg_ingress_rules_with_cidr_blocks = [{
    rule_count  = 1
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
    description = "Allow ssh traffic."
    },
    {
      rule_count  = 2
      from_port   = 27017
      to_port     = 27017
      protocol    = "tcp"
      cidr_blocks = ["172.16.0.0/16"]
      description = "Allow Mongodb traffic."
    }
  ]

  new_sg_ingress_rules_with_self = [{
    rule_count  = 1
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "Allow ssh traffic."
    },
    {
      rule_count  = 2
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "Allow Mongodbn traffic."
    }
  ]
}

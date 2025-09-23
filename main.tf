##-----------------------------------------------------------------------------
## Below resource will deploy new security group in aws.
##-----------------------------------------------------------------------------
resource "aws_security_group" "default" {
  count       = var.enabled && var.new_sg ? 1 : 0
  name        = "${var.name}-sg"
  vpc_id      = var.vpc_id
  description = var.sg_description
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )


  timeouts {
    create = var.create_timeout
    delete = var.delete_timeout
  }

  revoke_rules_on_delete = true
}

##-----------------------------------------------------------------------------
## Below data resource is to get details of existing security group in your aws environment.
##-----------------------------------------------------------------------------
data "aws_security_group" "existing" {
  count  = var.enabled && var.existing_sg_id != null ? 1 : 0
  id     = var.existing_sg_id
  vpc_id = var.vpc_id
}

##-----------------------------------------------------------------------------
## Below resource will deploy prefix list resource in aws.
##-----------------------------------------------------------------------------
resource "aws_ec2_managed_prefix_list" "prefix_list" {
  count          = var.enabled && var.prefix_list_enabled && length(var.prefix_list_ids) < 1 ? 1 : 0
  address_family = var.prefix_list_address_family
  max_entries    = var.max_entries
  name           = "${var.name}-prefix-list"

  dynamic "entry" {
    for_each = var.entry
    content {
      cidr        = lookup(entry.value, "cidr", null)        # Required - CIDR block for each entry
      description = lookup(entry.value, "description", null) # Optional - Description of each entry
    }
  }
}

##-----------------------------------------------------------------------------
## Below resource will deploy ingress security group rules for new security group created from this module.
##-----------------------------------------------------------------------------
# Security group rules with "cidr_blocks", but without "source_security_id" and "self"
resource "aws_security_group_rule" "new_sg_ingress_with_cidr_blocks" {
  for_each          = var.enabled ? { for rule in var.new_sg_ingress_rules_with_cidr_blocks : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  description       = lookup(each.value, "description", null)
}

# Security group rules with "self", but without "source_security_id" and "cidr_blocks"
resource "aws_security_group_rule" "new_sg_ingress_with_self" {
  for_each          = var.enabled ? { for rule in var.new_sg_ingress_rules_with_self : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  self              = lookup(each.value, "self", true)
  description       = lookup(each.value, "description", null)
}

# Security group rules with "source_security_id", but without "cidr_blocks" and "self"
resource "aws_security_group_rule" "new_sg_ingress_with_source_sg_id" {
  for_each                 = var.enabled ? { for rule in var.new_sg_ingress_rules_with_source_sg_id : rule.rule_count => rule } : {}
  type                     = "ingress"
  from_port                = each.value.from_port
  protocol                 = each.value.protocol
  to_port                  = each.value.to_port
  source_security_group_id = each.value.source_security_group_id
  security_group_id        = join("", aws_security_group.default[*].id)
  description              = lookup(each.value, "description", null)
}

# Security group rules with "prefix_list_ids", but without "cidr_blocks", "self" or "source_security_group_id"
resource "aws_security_group_rule" "new_sg_ingress_with_prefix_list" {
  for_each          = var.enabled ? { for rule in var.new_sg_ingress_rules_with_prefix_list : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  prefix_list_ids   = lookup(each.value, "prefix_list_ids", null) == null ? aws_ec2_managed_prefix_list.prefix_list[*].id : lookup(each.value, "prefix_list_ids", null)
  description       = lookup(each.value, "description", null)
}

##-----------------------------------------------------------------------------
## Below resource will deploy ingress security group rules for existing security group.
##-----------------------------------------------------------------------------
# Security group rules with "cidr_blocks", but without "source_security_id" and "self"
resource "aws_security_group_rule" "existing_sg_ingress_cidr_blocks" {
  for_each          = var.enabled ? { for rule in var.existing_sg_ingress_rules_with_cidr_blocks : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  description       = lookup(each.value, "description", null)
}

# Security group rules with "self", but without "source_security_id" and "cidr_blocks"
resource "aws_security_group_rule" "existing_sg_ingress_with_self" {
  for_each          = var.enabled ? { for rule in var.existing_sg_ingress_rules_with_self : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  self              = lookup(each.value, "self", true)
  description       = lookup(each.value, "description", null)
}

# Security group rules with "source_security_id", but without "cidr_blocks" and "self"
resource "aws_security_group_rule" "existing_sg_ingress_with_source_sg_id" {
  for_each                 = var.enabled ? { for rule in var.existing_sg_ingress_rules_with_source_sg_id : rule.rule_count => rule } : {}
  type                     = "ingress"
  from_port                = each.value.from_port
  protocol                 = try(each.value.protocol, "tcp")
  to_port                  = each.value.to_port
  source_security_group_id = each.value.source_security_group_id
  security_group_id        = join("", data.aws_security_group.existing[*].id)
  description              = try(each.value.description, "Allow ssh inbound traffic.")
}

# Security group rules with "prefix_list_ids", but without "cidr_blocks", "self" or "source_security_group_id"
resource "aws_security_group_rule" "existing_sg_ingress_with_prefix_list" {
  for_each          = var.enabled ? { for rule in var.existing_sg_ingress_rules_with_prefix_list : rule.rule_count => rule } : {}
  type              = "ingress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  prefix_list_ids   = lookup(each.value, "prefix_list_ids", null) == null ? aws_ec2_managed_prefix_list.prefix_list[*].id : lookup(each.value, "prefix_list_ids", null)
  description       = try(each.value.description, "Allow ssh inbound traffic.")
}

##-----------------------------------------------------------------------------
## Below resource will deploy egress security group rules for new security group created from this module.
##-----------------------------------------------------------------------------
# Security group rules with "cidr_blocks", but without "source_security_id" and "self"
#tfsec:ignore:aws-ec2-no-public-egress-sgr
#tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_security_group_rule" "new_sg_egress_with_cidr_blocks" {
  for_each          = var.enabled && var.existing_sg_id == null ? { for rule in var.new_sg_egress_rules_with_cidr_blocks : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  description       = lookup(each.value, "description", null)
}

# Security group rules with "self", but without "source_security_id" and "cidr_blocks"
resource "aws_security_group_rule" "new_sg_egress_with_self" {
  for_each          = var.enabled ? { for rule in var.new_sg_egress_rules_with_self : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  self              = lookup(each.value, "self", true)
  description       = lookup(each.value, "description", null)
}

# Security group rules with "source_security_id", but without "cidr_blocks" and "self"
resource "aws_security_group_rule" "new_sg_egress_with_source_sg_id" {
  for_each                 = var.enabled ? { for rule in var.new_sg_egress_rules_with_source_sg_id : rule.rule_count => rule } : {}
  type                     = "egress"
  from_port                = each.value.from_port
  protocol                 = try(each.value.protocol, "tcp")
  to_port                  = each.value.to_port
  source_security_group_id = each.value.source_security_group_id
  security_group_id        = join("", aws_security_group.default[*].id)
  description              = lookup(each.value, "description", null)
}

# Security group rules with "prefix_list_ids", but without "cidr_blocks", "self" or "source_security_group_id"
resource "aws_security_group_rule" "new_sg_egress_with_prefix_list" {
  for_each          = var.enabled ? { for rule in var.new_sg_egress_rules_with_prefix_list : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", aws_security_group.default[*].id)
  prefix_list_ids   = lookup(each.value, "prefix_list_ids", null) == null ? aws_ec2_managed_prefix_list.prefix_list[*].id : lookup(each.value, "prefix_list_ids", null)
  description       = lookup(each.value, "description", null)
}

##-----------------------------------------------------------------------------
## Below resource will deploy egress security group rules for existing security group.
##-----------------------------------------------------------------------------
# Security group rules with "cidr_blocks", but without "source_security_id" and "self"
resource "aws_security_group_rule" "existing_sg_egress_with_cidr_blocks" {
  for_each          = var.enabled ? { for rule in var.existing_sg_egress_rules_with_cidr_blocks : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  ipv6_cidr_blocks  = lookup(each.value, "ipv6_cidr_blocks", null)
  description       = lookup(each.value, "description", null)
}

# Security group rules with "self", but without "source_security_id" and "cidr_blocks"
resource "aws_security_group_rule" "existing_sg_egress_with_self" {
  for_each          = var.enabled ? { for rule in var.existing_sg_egress_rules_with_self : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = each.value.protocol
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  self              = lookup(each.value, "self", true)
  description       = lookup(each.value, "description", null)
}

# Security group rules with "source_security_id", but without "cidr_blocks" and "self"
resource "aws_security_group_rule" "existing_sg_egress_with_source_sg_id" {
  for_each                 = var.enabled ? { for rule in var.existing_sg_egress_rules_with_source_sg_id : rule.rule_count => rule } : {}
  type                     = "egress"
  from_port                = each.value.from_port
  protocol                 = try(each.value.protocol, "tcp")
  to_port                  = each.value.to_port
  source_security_group_id = each.value.source_security_group_id
  security_group_id        = join("", data.aws_security_group.existing[*].id)
  description              = lookup(each.value, "source_address_prefix", null)
}

# Security group rules with "prefix_list_ids", but without "cidr_blocks", "self" or "source_security_group_id"
resource "aws_security_group_rule" "existing_sg_egress_with_prefix_list" {
  for_each          = var.enabled ? { for rule in var.existing_sg_egress_rules_with_prefix_list : rule.rule_count => rule } : {}
  type              = "egress"
  from_port         = each.value.from_port
  protocol          = try(each.value.protocol, "tcp")
  to_port           = each.value.to_port
  security_group_id = join("", data.aws_security_group.existing[*].id)
  prefix_list_ids   = lookup(each.value, "prefix_list_ids", null) == null ? aws_ec2_managed_prefix_list.prefix_list[*].id : lookup(each.value, "prefix_list_ids", null)
  description       = lookup(each.value, "source_address_prefix", null)
}

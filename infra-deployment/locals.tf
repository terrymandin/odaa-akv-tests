
locals {
	oracle_subnet_name_effective          = coalesce(var.oracle_subnet_name, var.adbs_subnet_name, "oracle-subnet")
	oracle_subnet_prefix_length_effective = var.oracle_subnet_prefix_length
	jumpbox_admin_password_effective      = var.jumpbox_admin_password
}
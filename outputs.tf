
output "icp_public_key" {
  description = "The public key used for boot master to connect via ssh for cluster setup"
  value = "${var.generate_key ? tls_private_key.icpkey.public_key_openssh : var.icp_pub_key}"
}

output "icp_private_key" {
  description = "The public key used for boot master to connect via ssh for cluster setup"
  value = "${var.generate_key ? tls_private_key.icpkey.private_key_pem : var.icp_priv_key}"
}

output "install_complete" {
  depends_on  = ["null_resource.icp-install"]
  description = "Boolean value that is set to true when ICP installation process is completed"
  value       = "true"
}

output "icp_version" {
  value = "${var.icp-inception}"
}

output "cluster_ips" {
  value = "${local.icp-ips}"
}

locals {
  default_admin_password = "${lookup(var.icp_configuration, "default_admin_password", random_string.generated_password.result)}"
}

output "default_admin_password" {
  value = "${local.default_admin_password != "" ? local.default_admin_password : random_string.generated_password.result}"
}

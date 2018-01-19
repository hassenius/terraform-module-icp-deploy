# Username and password for the initial admin user
variable "icpuser" { 
  type        = "string"
  description = "Username of initial admin user. Default: Admin"
  default     = "admin" 
}
variable "icppassword" { 
  type        = "string"
  description = "Password of initial admin user. Default: Admin"
  default     = "admin" 
}

variable "icp-master" { 
  type        = "list"
  description =  "IP address of ICP Masters. First master will also be boot master. CE edition only supports single master "
}

variable "icp-worker" { 
  type        = "list"
  description =  "IP addresses of ICP Worker nodes."
}

variable "icp-proxy" { 
  type        = "list"
  description =  "IP addresses of ICP Proxy nodes."
}

variable "icp-management" {
  type        = "list"
  description = "IP addresses of ICP Management Nodes, if management is to be separated from master nodes. Optional"
  default     = []
}


variable "enterprise-edition" {
  description = "Whether to provision enterprise edition (EE) or community edition (CE). EE requires image files to be provided"
  default     = false
}

variable "parallell-image-pull" {
  description = "Download and pull docker images on all nodes in parallell before starting ICP installation."
  default     = false
}

variable "image_file" {
  description = "Filename of image. Only required for enterprise edition"
  default     = "/dev/null"
}

variable "image_location" {
  description = "Alternative to image_file, if image is accessible to the new vm over nfs or http"
  default     = "false"
}

variable "docker_package_location" {
  description = "http or nfs location of docker installer which ships with ICP. Option for RHEL which does not support docker-ce"
  default     = ""
}

variable  "icp-version" {
  description = "Version of ICP to provision. For example 1.2.0, 1.2.0-ee, 2.1.0-beta1"
  default = "2.1.0"
}

variable "ssh_user" {
  description = "Username to ssh into the ICP cluster. This is typically the default user with for the relevant cloud vendor"
  default     = "root"
}

variable "ssh_key" {
  description = "Private key corresponding to the public key that the cloud servers are provisioned with. DEPRECATED. Use ssh_key_file or ssh_key_base64"
  default     = "~/.ssh/id_rsa"
}

variable "ssh_key_base64" {
  description = "base64 encoded content of private ssh key"
  default     = ""
}

variable "ssh_key_file" {
  description = "Location of private ssh key. i.e. ~/.ssh/id_rsa"
  default     = ""
  
}

variable "ssh_agent" {
  description = "Enable or disable SSH Agent. Can correct some connectivity issues. Default: true"
  default     = true
}

variable "bastion_host" {
  description = "Specify hostname or IP to connect to nodes through a SSH bastion host. Assumes same SSH key and username as cluster nodes"
  default     = ""
}


variable "generate_key" {
  description = "Whether to generate a new ssh key for use by ICP Boot Master to communicate with other nodes"
  default     = false
}

variable "icp_pub_keyfile" {
  description = "Public ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false"
  default     = "/dev/null"
}

variable "icp_priv_keyfile" {
  description = "Private ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false"
  default     = "/dev/null"
}

variable "cluster_size" {
  description = "Define total clustersize. Workaround for terraform issue #10857."
}

/*
  ICP Configuration 
  Configuration file is generated from items in the following order
  1. config.yaml shipped with ICP (if config_strategy = merge, else blank)
  2. config.yaml specified in icp_config_file
  3. key: value items specified in icp_configuration

*/
variable "icp_config_file" {
  description = "Yaml configuration file for ICP installation"
  default     = "/dev/null"
}

variable "icp_configuration" {
  description = "Configuration items for ICP installation."
  type        = "map"
  default     = {}
}

variable "config_strategy" {
  description  = "Strategy for original config.yaml shipped with ICP. Default is merge, everything else means override"
  default      = "merge"
  
}


locals {
  icp-ips       = "${concat(var.icp-master, var.icp-proxy, var.icp-worker, var.icp-management)}"
  cluster_size  = "${length(concat(var.icp-master, var.icp-proxy, var.icp-worker, var.icp-management))}"
  ssh_key       = "${var.ssh_key_base64 == "" ? file(coalesce(var.ssh_key_file, "/dev/null")) : base64decode(var.ssh_key_base64)}"
  
}

# Terraform ICP Provision Module
This terraform module can be used to deploy IBM Cloud Private on any supported infrastructure vendor.
Currently tested with Ubuntu 16.06 on SoftLayer VMs, deploying ICP 1.2.0 and 2.1.0-beta-1 Community Editions.

### Pre-requisits

If the default SSH user is not the root user, the default user must have password-less sudo access.


## Inputs

| variable  |  default  | required |  description    |
|-----------|-----------|---------|--------|
|  icp-version   |      |  Yes  |   Version of ICP to provision. For example 1.2.0, 1.2.0-ee, 2.1.0-beta1                | 
|  icp-master   |      |  Yes  |   IP address of ICP Masters. First master will also be boot master. CE edition only supports single master                 | 
|  icp-worker   |      |  Yes  |   IP addresses of ICP Worker nodes.                | 
|  cluster_size   |      |  Yes  |   Define total clustersize. Workaround for terraform issue #10857.                | 
|  icp-proxy   |      |  Yes  |   IP addresses of ICP Proxy nodes.                | 
|  icp_configuration   |   {}   |  No  |   Configuration items for ICP installation.                | 
|  enterprise-edition   |   False   |  No  |   Whether to provision enterprise edition (EE) or community edition (CE). EE requires image files to be provided                | 
|  ssh_key   |   ~/.ssh/id_rsa   |  No  |   Private key corresponding to the public key that the cloud servers are provisioned with                | 
|  icpuser   |   admin   |  No  |   Username of initial admin user. Default: Admin                | 
|  config_strategy   |   merge   |  No  |   Strategy for original config.yaml shipped with ICP. Default is merge, everything else means override                | 
|  icppassword   |   admin   |  No  |   Password of initial admin user. Default: Admin                | 
|  ssh_user   |   root   |  No  |   Username to ssh into the ICP cluster. This is typically the default user with for the relevant cloud vendor                | 
|  icp_pub_keyfile   |   /dev/null   |  No  |   Public ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false                | 
|  generate_key   |   False   |  No  |   Whether to generate a new ssh key for use by ICP Boot Master to communicate with other nodes                | 
|  image_file   |   /dev/null   |  No  |   Filename of image. Only required for enterprise edition                | 
|  icp_priv_keyfile   |   /dev/null   |  No  |   Private ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false                | 
|  icp_config_file   |   /dev/null   |  No  |   Yaml configuration file for ICP installation                | 



## Usage example

```hcl
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-icp-deploy"
    
    icp-master = ["${softlayer_virtual_guest.icpmaster.ipv4_address}"]
    icp-worker = ["${softlayer_virtual_guest.icpworker.*.ipv4_address}"]
    icp-proxy = ["${softlayer_virtual_guest.icpproxy.*.ipv4_address}"]
    
    enterprise-edition = false
    #icp-version = "2.1.0-beta-1"
    icp-version = "1.2.0"

    /* Workaround for terraform issue #10857
     When this is fixed, we can work this out autmatically */
    cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"]}"

    icp_configuration = {
      "network_cidr"              = "192.168.0.0/16"
      "service_cluster_ip_range"  = "172.16.0.1/24"
    }

    generate_key = true
    
    ssh_user  = "ubuntu"
    ssh_key   = "~/.ssh/id_rsa"
    
} 
```

### ICP Configuration 
Configuration file is generated from items in the following order

1. config.yaml shipped with ICP (if config_strategy = merge, else blank)
2. config.yaml specified in icp_config_file
3. key: value items specified in icp_configuration


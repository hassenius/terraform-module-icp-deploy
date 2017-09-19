# Terraform ICP Provision Module
This terraform module can be used to deploy IBM Cloud Private on any supported infrastructure vendor.
Currently tested with Ubuntu 16.06 on SoftLayer VMs, deploying ICP 1.2.0 and 2.1.0-beta-1 Community Editions.

### Pre-requisits

If the default SSH user is not the root user, the default user must have password-less sudo access.


## Inputs
Look in [variables.tf](variables.tf) for details


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


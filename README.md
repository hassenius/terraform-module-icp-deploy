# Terraform ICP Provision Module
This terraform module can be used to deploy IBM Cloud Private on any supported infrastructure vendor.
Tested on Ubuntu 16.04 and RHEL 7 on SoftLayer, VMware, AWS and Azure.

### Pre-requisites

If the default SSH user is not the root user, the default user must have password-less sudo access.


## Inputs

| Variable           | Default       |Required| Description                            |
|--------------------|---------------|--------|----------------------------------------|
| **Cluster settings** |
|icp-version         |2.1.0          |No      |Version of ICP to provision. See below for details on using private registry|
|icp-master          |               |Yes     |IP address of ICP Masters. First master will also be boot master. CE edition only supports single master |
|icp-worker          |               |Yes     |IP addresses of ICP Worker nodes.       |
|icp-proxy           |               |Yes     |IP addresses of ICP Proxy nodes.        |
|icp-management      |               |No      |IP addresses of ICP Management Nodes, if management is to be separated from master nodes. Optional|
|cluster_size        |               |Yes     |Define total clustersize. Workaround for terraform issue #10857. Normally computed|
| **ICP Configuration ** |
|icp_config_file     |               |No      |Yaml configuration file for ICP installation|
|icp_configuration   |               |No      |Configuration items for ICP installation. See [KnowledgeCenter](https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html) for reference|
|config_strategy     |merge          |No      |Strategy for original config.yaml shipped with ICP. Default is merge, everything else means override. |
| **ICP Boot node to cluster communication** |
|generate_key        |True           |No      |Whether to generate a new ssh key for use by ICP Boot Master to communicate with other nodes|
|icp_pub_key         |               |No      |Public ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false|
|icp_priv_key        |               |No      |Private ssh key for ICP Boot master to connect to ICP Cluster. Only use when generate_key = false|
| **Terraform installation process** |
|hooks               | |No      |Hooks into different stages in the cluster setup process. See below for details|
| **Terraform to cluster ssh configuration**|
|ssh_user            |root           |No      |Username for Terraform to ssh into the ICP cluster. This is typically the default user with for the relevant cloud vendor|
|ssh_key_base64      |               |No      |base64 encoded content of private ssh key|
|ssh_key_file        |               |No      |Location of private ssh key. i.e. ~/.ssh/id_rsa|
|ssh_agent           |True           |No      |Enable or disable SSH Agent. Can correct some connectivity issues. Default: true (enabled)|
|ssh_key             |~/.ssh/id_rsa  |No      |Private key corresponding to the public key that the cloud servers are provisioned with. DEPRECATED. Use ssh_key_file or ssh_key_base64|
|bastion_host        |               |No      |Specify hostname or IP to connect to nodes through a SSH bastion host. Assumes same SSH key and username as cluster nodes|
| **Docker and ICP Enterprise Edition Image configuration** |
|docker_package_location|               |No      |http or nfs location of docker installer which ships with ICP. Typically used for RHEL which does not support docker-ce|
|image_location      |False          |No      |Location of image file. Start with nfs: or http: to indicate protocol to download with|
|image_file          |/dev/null      |No      |Filename of image. Only required for enterprise edition|
|enterprise-edition  |False          |No      |Whether to provision enterprise edition (EE) or community edition (CE). EE requires image files to be provided|
|parallell-image-pull|False          |No      |Download and pull docker images on all nodes in parallell before starting ICP installation. Can speed up installation time|


### ICP Version specifications
The `icp-version` field supports the format `org`/`repo`:`version`. `ibmcom` is the default organisation and `icp-inception` is the default repo, so if you're installing for example version `2.1.0.2` from Docker Hub it's sufficient to specify `2.1.0.2` as the version number.

It is also supported to install from private docker registries.
In this case the format is:
`username`:`password`@`private_registry_server`/`org`/`repo`:`version`.

So for exmaple

`myuser:SomeLongPassword@myprivateregistry.local/ibmcom/icp-inception:2.1.0.2`


### Hooks
It is possible to execute arbritrary commands between various phases of the cluster setup and installation process.
Currently, the following hooks are defined

| Hook name                 | Where executed | When executed |
| icp-cluster-preconfig-hook| all nodes      | Before any of the module scripts |
| icp-cluster-postconfig-hook | all nodes    | After preprequisites are installed |
| icp-boot-preconfig        | boot master    | Before any module scripts on boot master |
| icp-preinstall-hook       | boot master    | After configuration image load and configuration generation|
| icp-postinstall-hook      | boot master    | After successful ICP installation                          |




## Usage example

### Using hooks

```hcl
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy?ref=2.0.0"

    icp-master  = ["${softlayer_virtual_guest.icpmaster.ipv4_address}"]
    icp-worker  = ["${softlayer_virtual_guest.icpworker.*.ipv4_address}"]
    icp-proxy   = ["${softlayer_virtual_guest.icpproxy.*.ipv4_address}"]

    icp-version = "2.1.0.1"

    cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"]}"

    icp_configuration = {
      "network_cidr"              = "192.168.0.0/16"
      "service_cluster_ip_range"  = "172.16.0.1/24"
      "default_admin_password"    = "My0wnPassw0rd"
    }

    generate_key = true

    ssh_user     = "ubuntu"
    ssh_key_file = "~/.ssh/id_rsa"
    hooks = {
      "cluster-preconfig" = [
        "echo This will run on all nodes",
        "echo And I can run as many commands",
        "echo as I want",
        "echo ....they will run in order"
      ]
      "postinstall" = [
        "echo Performing some post install backup",
        "${ var.postinstallbackup != "true" ? "" : "sudo chmod a+x /tmp/icp_backup.sh ; sudo /tmp/icp_backup.sh" }"
      ]
    }
}
```


#### Community Edition

```hcl
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy?ref=2.0.0"

    icp-master  = ["${softlayer_virtual_guest.icpmaster.ipv4_address}"]
    icp-worker  = ["${softlayer_virtual_guest.icpworker.*.ipv4_address}"]
    icp-proxy   = ["${softlayer_virtual_guest.icpproxy.*.ipv4_address}"]

    icp-version = "2.1.0.1"

    cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"]}"

    icp_configuration = {
      "network_cidr"              = "192.168.0.0/16"
      "service_cluster_ip_range"  = "172.16.0.1/24"
      "default_admin_password"    = "My0wnPassw0rd"
    }

    generate_key = true

    ssh_user     = "ubuntu"
    ssh_key_file = "~/.ssh/id_rsa"

}
```

#### Enterprise Edition

```hcl
module "icpprovision" {
    source = "github.com/ibm-cloud-architecture/terraform-module-icp-deploy?ref=2.0.0"

    icp-master = ["${softlayer_virtual_guest.icpmaster.ipv4_address}"]
    icp-worker = ["${softlayer_virtual_guest.icpworker.*.ipv4_address}"]
    icp-proxy  = ["${softlayer_virtual_guest.icpproxy.*.ipv4_address}"]

    icp-version    = "2.1.0.1-ee"
    image_location = "nfs:fsf-lon0601b-fz.adn.networklayer.com:/IBM02S6275/data01/ibm-cloud-private-x86_64-2.1.0.1.tar.gz"
    parallell-pull = True

    cluster_size  = "${var.master["nodes"] + var.worker["nodes"] + var.proxy["nodes"]}"

    icp_configuration = {
      "network_cidr"              = "192.168.0.0/16"
      "service_cluster_ip_range"  = "172.16.0.1/24"
      "default_admin_password"    = "My0wnPassw0rd"
    }

    generate_key = true

    ssh_user     = "ubuntu"
    ssh_key_file = "~/.ssh/id_rsa"

}
```

There are several examples for different providers available from [IBM Cloud Architecture Solutions Group github page](https://github.com/ibm-cloud-architecture)
- [ICP on SoftLayer](https://github.com/ibm-cloud-architecture/terraform-icp-softlayer)
- [ICP on VMware](https://github.com/ibm-cloud-architecture/terraform-icp-vmware)


### ICP Configuration
Configuration file is generated from items in the following order

1. config.yaml shipped with ICP (if config_strategy = merge, else blank)
2. config.yaml specified in `icp_config_file`
3. key: value items specified in `icp_configuration`

Details on configuration items on ICP KnowledgeCenter
* [ICP 1.2.0](https://www.ibm.com/support/knowledgecenter/SSBS6K_1.2.0/installing/config_yaml.html)
* [ICP 2.1.0](https://www.ibm.com/support/knowledgecenter/SSBS6K_2.1.0/installing/config_yaml.html)


### Scaling
The module supports automatic scaling of worker nodes.
To scale simply add more nodes in the root resource supplying the `icp-worker` variable.
You can see working examples for softlayer [in the icp-softlayer](https://github.com/ibm-cloud-architecture/terraform-icp-softlayer) repository

Please note, because of how terraform handles module dependencies and triggers, it is currently necessary to retrigger the scaling resource **after scaling down** nodes.
If you don't do this ICP will continue to report inactive nodes until the next scaling event.
To manually trigger the removal of deleted node, run these commands:

1. `terraform taint --module icpprovision null_resource.icp-worker-scaler`
2. `terraform apply`

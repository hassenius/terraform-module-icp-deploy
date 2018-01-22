

# Generate a new key if this is required
resource "tls_private_key" "icpkey" {
  count       = "${var.generate_key ? 1 : 0}"
  algorithm   = "RSA"

  provisioner "local-exec" {
    command = "cat > privatekey.pem <<EOL\n${tls_private_key.icpkey.private_key_pem}\nEOL"
  }
}

## Actions that has to be taken on all nodes in the cluster
resource "null_resource" "icp-cluster" {

  count = "${var.cluster_size}"

  connection {
      host          = "${element(local.icp-ips, count.index)}"
      user          = "${var.ssh_user}"
      private_key   = "${local.ssh_key}"
      agent         = "${var.ssh_agent}"
      bastion_host  = "${var.bastion_host}"
  }

  # Validate we can do passwordless sudo in case we are not root
  provisioner "remote-exec" {
    inline = [
      "sudo -n echo This will fail unless we have passwordless sudo access"
    ]
  }

  provisioner "file" {
      content = "${var.generate_key ? tls_private_key.icpkey.public_key_openssh : file(var.icp_pub_keyfile)}"
      destination = "/tmp/icpkey"

  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/icp-common-scripts"
    ]
  }
  provisioner "file" {
    source      = "${path.module}/scripts/common/"
    destination = "/tmp/icp-common-scripts"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "cat /tmp/icpkey >> ~/.ssh/authorized_keys",
      "chmod a+x /tmp/icp-common-scripts/*",
      "/tmp/icp-common-scripts/prereqs.sh",
      "/tmp/icp-common-scripts/version-specific.sh ${var.icp-version}",
      "/tmp/icp-common-scripts/docker-user.sh"
    ]
  }
}

resource "null_resource" "icp-docker" {
  depends_on = ["null_resource.icp-cluster"]

  count = "${var.parallell-image-pull ? var.cluster_size : "1"}"

  # Boot node is always the first entry in the IP list, so if we're not pulling in parallell this will only happen on boot node
  connection {
    host          = "${element(local.icp-ips, count.index)}"
    user          = "${var.ssh_user}"
    private_key   = "${local.ssh_key}"
    agent         = "${var.ssh_agent}"
    bastion_host  = "${var.bastion_host}"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/icp-bootmaster-scripts",
      "sudo mkdir -p /opt/ibm/cluster",
      "sudo chown ${var.ssh_user} /opt/ibm/cluster"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/scripts/boot-master/"
    destination = "/tmp/icp-bootmaster-scripts"
  }

  # Make sure scripts are executable and docker installed
  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/icp-bootmaster-scripts/*.sh",
      "/tmp/icp-bootmaster-scripts/install-docker.sh \"${var.docker_package_location}\" "
    ]
  }
}


resource "null_resource" "icp-image" {
  depends_on = ["null_resource.icp-docker"]

  count = "${var.parallell-image-pull ? var.cluster_size : "1"}"

  # Boot node is always the first entry in the IP list, so if we're not pulling in parallell this will only happen on boot node
  connection {
    host          = "${element(local.icp-ips, count.index)}"
    user          = "${var.ssh_user}"
    private_key   = "${local.ssh_key}"
    agent         = "${var.ssh_agent}"
    bastion_host  = "${var.bastion_host}"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/icp-bootmaster-scripts",
    ]
  }

  provisioner "file" {
    source      = "${path.module}/scripts/boot-master/"
    destination = "/tmp/icp-bootmaster-scripts"
  }

  # If this is enterprise edition we'll need to copy the image file over and load it in local repository
  // We'll need to find another workaround while tf does not support count for this
  provisioner "file" {
      # count = "${var.enterprise-edition ? 1 : 0}"
      source = "${var.enterprise-edition ? var.image_file : "/dev/null" }"
      destination = "/tmp/${basename(var.image_file)}"
  }

  provisioner "remote-exec" {
    inline = [
      "echo \"Loading image ${var.icp-version}\"",
      "chmod a+x /tmp/icp-bootmaster-scripts/load-image.sh",
      "/tmp/icp-bootmaster-scripts/load-image.sh ${var.icp-version} /tmp/${basename(var.image_file)} \"${var.image_location}\" "
    ]
  }
}

# First make sure scripts and configuration files are copied
resource "null_resource" "icp-boot" {

  depends_on = ["null_resource.icp-image"]

  # The first master is always the boot master where we run provisioning jobs from
  connection {
    host          = "${element(var.icp-master, 0)}"
    user          = "${var.ssh_user}"
    private_key   = "${local.ssh_key}"
    agent         = "${var.ssh_agent}"
    bastion_host  = "${var.bastion_host}"
  }

  # store config yaml if it was specified
  provisioner "file" {
    source       = "${var.icp_config_file}"
    destination = "/tmp/config.yaml"
  }

  # JSON dump the contents of icp_configuration items
  provisioner "file" {
    content     = "${jsonencode(var.icp_configuration)}"
    destination = "/tmp/items-config.yaml"
  }
}



# Generate all necessary configuration files, load image files, etc
resource "null_resource" "icp-config" {
  depends_on = ["null_resource.icp-boot"]

  # The first master is always the boot master where we run provisioning jobs from
  connection {
    host          = "${element(local.icp-ips, 0)}"
    user          = "${var.ssh_user}"
    private_key   = "${local.ssh_key}"
    agent         = "${var.ssh_agent}"
    bastion_host  = "${var.bastion_host}"
  }

  provisioner "remote-exec" {
    inline = [
      "/tmp/icp-bootmaster-scripts/copy_cluster_skel.sh ${var.icp-version}",
      "sudo chown ${var.ssh_user} /opt/ibm/cluster/*",
      "chmod 600 /opt/ibm/cluster/ssh_key",
      "sudo pip install pyyaml",
      "python /tmp/icp-bootmaster-scripts/load-config.py ${var.config_strategy}"
    ]
  }

  # Copy the provided or generated private key
  provisioner "file" {
      content = "${var.generate_key ? tls_private_key.icpkey.private_key_pem : file(var.icp_priv_keyfile)}"
      destination = "/opt/ibm/cluster/ssh_key"
  }

  provisioner "file" {
    content = "${join(",", var.icp-worker)}"
    destination = "/opt/ibm/cluster/workerlist.txt"
  }

  provisioner "file" {
    content = "${join(",", var.icp-master)}"
    destination = "/opt/ibm/cluster/masterlist.txt"
  }

  provisioner "file" {
    content = "${join(",", var.icp-proxy)}"
    destination = "/opt/ibm/cluster/proxylist.txt"
  }

  # Since the file provisioner deals badly with empty lists, we'll create the optional management nodes differently
  # Later we may refactor to use this method for all node types for consistency
  provisioner "remote-exec" {
    inline = [
      "echo -n ${join(",", var.icp-management)} > /opt/ibm/cluster/managementlist.txt"
    ]
  }
}

# Generate the hosts files on the cluster
resource "null_resource" "icp-generate-hosts-files" {
  depends_on = ["null_resource.icp-config"]

  # The first master is always the boot master where we run provisioning jobs from
  connection {
    host          = "${element(var.icp-master, 0)}"
    user          = "${var.ssh_user}"
    private_key   = "${local.ssh_key}"
    agent         = "${var.ssh_agent}"
    bastion_host  = "${var.bastion_host}"
  }

  provisioner "remote-exec" {
    inline = [
      "/tmp/icp-bootmaster-scripts/generate_hostsfiles.sh"
    ]
  }
}

# Start the installer
resource "null_resource" "icp-install" {
  depends_on = ["null_resource.icp-generate-hosts-files"]

  # The first master is always the boot master where we run provisioning jobs from
  connection {
    host          = "${element(var.icp-master, 0)}"
    user          = "${var.ssh_user}"
    private_key   = "${local.ssh_key}"
    agent         = "${var.ssh_agent}"
    bastion_host  = "${var.bastion_host}"
  }

  provisioner "remote-exec" {
    inline = [
      "/tmp/icp-bootmaster-scripts/start_install.sh ${var.icp-version}"
    ]
  }
}

resource "null_resource" "icp-worker-scaler" {
  depends_on = ["null_resource.icp-cluster", "null_resource.icp-boot"]

  triggers {
    workers = "${join(",", var.icp-worker)}"
  }

  connection {
    host = "${element(var.icp-master, 0)}"
    user = "${var.ssh_user}"
    private_key   = "${local.ssh_key}"
    agent = "${var.ssh_agent}"
  }

  provisioner "file" {
    content = "${join(",", var.icp-worker)}"
    destination = "/tmp/workerlist.txt"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/boot-master/scaleworkers.sh"
    destination = "/tmp/icp-bootmaster-scripts/scaleworkers.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod a+x /tmp/icp-bootmaster-scripts/scaleworkers.sh",
      "/tmp/icp-bootmaster-scripts/scaleworkers.sh ${var.icp-version}"
    ]
  }



}

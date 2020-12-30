## DATASOURCE
# Init Script Files
data "template_file" "setup_script_kafka" {
  template = file("../scripts/kafka_oci_init.sh")

  vars = {
    kafka_mgmt_password = random_string.myvm_password.result
    count    = var.instance["instance_count"] 
    name = var.instance["name"]
    private_ips  = join(" ",oci_core_instance.myvm.*.private_ip)
 }
}

data "template_file" "setup_script_cmak" {
  template = file("../scripts/kafka_oci_cmak.sh")

  vars = {
    kafka_mgmt_password = random_string.myvm_password.result
    count    = var.instance["instance_count"]
    name = var.instance["name"]
    private_ips  = join(" ",oci_core_instance.myvm.*.private_ip)
 }
}


locals {
  setup_script_source    = "../scripts/kafka_oci_init.sh"
  setup_script_dest    = "~/kafka_oci_init.sh"
  cmak_script_dest    = "~/kafka_oci_cmak.sh"
  instance_count    = var.instance["instance_count"] 
  password = random_string.myvm_password.result
  private_ips  = join(" ",oci_core_instance.myvm.*.private_ip)
  # vars = {
  # ips  = join(" ",oci_core_instance.myvm.*.private_ip)
  #}
}


resource "oci_core_instance" "myvm" {
  count               = var.instance["instance_count"]
  availability_domain = element(data.template_file.ad_names.*.rendered, count.index)
  fault_domain        = "FAULT-DOMAIN-${(count.index % 3) + 1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.instance["name"]}${count.index}"
  shape               = var.instance["shape"]

  create_vnic_details {
    subnet_id        = oci_core_subnet.Subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "${var.instance["name"]}${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = var.images[var.region]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
#    user_data           = base64encode(data.template_file.user_data.rendered)
#     user_data = templatefile("${path.module}/../scripts/test.sh",vars)
  }

/*
  provisioner "file" {
    #source      = local.setup_script_source
    content     = data.template_file.setup_script_kafka.rendered
    destination = local.setup_script_dest


    connection  {
      type        = "ssh"
      #host        = self.private_ip
      host        = self.public_ip
      agent       = false
      timeout     = "5m"
      user        = "opc" 
      private_key = file(var.ssh_private_key_path)
    }
  }


  provisioner "remote-exec" {
    connection  {
      type        = "ssh"
      #host        = self.private_ip
      host        = self.public_ip
      agent       = false
      timeout     = "5m"
      user        = "opc"
      private_key = file(var.ssh_private_key_path)
    }

   
    inline = [
       "chmod +x ${local.setup_script_dest}",
       "cat ${local.setup_script_dest}"
    ]

   }
*/

}


resource "null_resource" "init_kafka_cluster" {
count = var.instance["instance_count"] 
connection {
    type        = "ssh"
    host        = oci_core_instance.myvm[ count.index  ].public_ip
    user        = "opc"
    private_key = file(var.ssh_private_key_path)
  }


  provisioner "file" {
    #source      = local.setup_script_source
    content     = data.template_file.setup_script_kafka.rendered
    destination = local.setup_script_dest
  }

provisioner "remote-exec" {
    inline = [
      "echo 'This instance was provisioned by Terraform.  ${count.index}    ${oci_core_instance.myvm[count.index].private_ip}      '  >> /tmp/tmptmp",
      "chmod +x ${local.setup_script_dest}",
      "sudo  ${local.setup_script_dest} ${count.index}"
    ]
  }

}


resource "null_resource" "start_kafka_cluster" {
  depends_on = [null_resource.init_kafka_cluster]
  count = var.instance["instance_count"]
  connection {
    type        = "ssh"
    host        = oci_core_instance.myvm[ count.index  ].public_ip
    user        = "opc"
    private_key = file(var.ssh_private_key_path)
  }

provisioner "remote-exec" {
    inline = [
     # "mkdir /opt/oci_kafka/config/zookeeperdata; echo ${count.index} >  /opt/oci_kafka/config/zookeeperdata/myid/; " ,
      "sudo systemctl start zookeeper;sudo systemctl enable zookeeper;",
      "sudo systemctl start kafka;sudo systemctl enable kafka;"
    ]
  }

}



resource "null_resource" "install_kafka_mgmt" {
  depends_on = [null_resource.start_kafka_cluster]
  connection {
    type        = "ssh"
    host        = oci_core_instance.myvm[0].public_ip
    user        = "opc"
    private_key = file(var.ssh_private_key_path)
  }


 provisioner "file" {
    #source      = local.setup_script_source
    content     = data.template_file.setup_script_cmak.rendered
    destination = local.cmak_script_dest
  }


provisioner "remote-exec" {
    inline = [
          "chmod +x ${local.cmak_script_dest}",
          "sudo  ${local.cmak_script_dest} ",
          "sudo systemctl enable cmak ",
          "sudo systemctl start cmak" 
    ]
  }

}




resource "random_string" "myvm_password" {
  length  = 64
  special = false
}


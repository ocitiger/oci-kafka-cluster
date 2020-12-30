locals {
  tcp_protocol  = "6"
  all_protocols = "all"
  anywhere      = "0.0.0.0/0"
}

resource "oci_core_security_list" "SecurityList" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.VCN.id
  display_name   = "${var.instance["name"]}SecurityList"

  egress_security_rules {
    protocol    = local.tcp_protocol
    destination = local.anywhere
  }

  ingress_security_rules {
    protocol = local.tcp_protocol
    source   = local.anywhere

    tcp_options {
      max = "22"
      min = "22"
    }
  }

  ingress_security_rules {
    protocol = local.tcp_protocol
    #source   = local.anywhere
    source   = var.CIDR

    tcp_options {
      max = "9092"
      min = "9092"
    }
  }

  ingress_security_rules {
    protocol = local.tcp_protocol
    #source   = local.anywhere
    source   = var.CIDR
    
    tcp_options {
      max = "2181"
      min = "2181"
    }
  }

  ingress_security_rules {
    protocol = local.tcp_protocol
    #source   = local.anywhere
    source   = var.CIDR
    tcp_options {
      max = "2888"
      min = "2888"
    }  
  }


  ingress_security_rules {
    protocol = local.tcp_protocol
    #source   = local.anywhere
    source   = var.CIDR
    tcp_options {
      max = "3888"
      min = "3888"
    }
  }




  ingress_security_rules {
    protocol = local.tcp_protocol
    #source   = var.CIDR
    source   = local.anywhere

    tcp_options {
      max = "9000"
      min = "9000"
    }
  }

}


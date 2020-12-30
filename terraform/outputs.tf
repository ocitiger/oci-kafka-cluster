output "Kafka-IP" {
  value = "Now you can access CMAK from http://${data.oci_core_vnic.myvm_vnic.public_ip_address}:9000"
}

output "Kafka-Management-Password" {
  value     = "User:ocikafkaadmin Password:${random_string.myvm_password.result}"
  sensitive = false
}


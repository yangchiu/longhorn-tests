output "network_interface_ids" {
  depends_on = [
    aws_network_interface.instance_eth0,
    aws_network_interface.instance_eth1
  ]
  value = join(" ", concat(aws_network_interface.instance_eth0[*].id, aws_network_interface.instance_eth1[*].id))
}

output "resource_suffix" {
  depends_on = [
    random_string.random_suffix
  ]

  value = random_string.random_suffix.id
}

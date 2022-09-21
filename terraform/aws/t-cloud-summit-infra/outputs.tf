output "shh" {
  value = "ssh -i ${module.ssh_key.private_key_filename} ${var.acebox_user}@${aws_instance.acebox.public_ip}"
}

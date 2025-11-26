variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for instances (leave empty to disable SSH access)"
  type        = string
  default     = "awslogin"
}


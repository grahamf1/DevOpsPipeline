variable "admin_password" {
  description = "Password for the admin user"
  type        = string
  sensitive   = true
}

variable "jenkins_password" {
  description = "Password for the Jenkins user"
  type        = string
  sensitive   = true
}
variable "root_url" {
  type        = string
  description = "The root url for the website."
  default     = "neurowinter.dev"
}

variable "subdomains" {
  type        = list(any)
  description = "The list of subdomains that you want the site to be deployed to."
  # I wanted to use the root url here, but terraform does not like nested variables.
  default = ["www.neurowinter.dev"]
}

variable "deployment_user" {
  type        = string
  description = "The user that you want to deploy the infrastructure."
  default     = "arn:aws:iam::058786660650:user/personal_deployment"
}

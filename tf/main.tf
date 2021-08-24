terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "neurowinter-personal"
  region  = "ap-southeast-2"
}

# For cloudfront, the acm has to be created in us-east-1 or it will not work
provider "aws" {
  profile = "neurowinter-personal"
  alias   = "us"
  region  = "us-east-1"
}

module "acm_request_certificate" {
  source = "cloudposse/acm-request-certificate/aws"
  # Documentation: https://github.com/cloudposse/terraform-aws-acm-request-certificate/blob/master/README.md
  providers = {
    aws = aws.us
  }
  # Cloud Posse recommends pinning every module to a specific version
  version = "0.15.0"

  domain_name                       = var.root_url
  subject_alternative_names         = var.subdomains
  process_domain_validation_options = true
  ttl                               = "300"
}

module "cdn" {
  source = "cloudposse/cloudfront-s3-cdn/aws"
  # Documentation: https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn/blob/master/README.md
  # Cloud Posse recommends pinning every module to a specific version
  version = "0.74.3"

  namespace         = "NeuroWinter"
  stage             = "prod"
  name              = "personal-site"
  aliases           = var.subdomains
  dns_alias_enabled = true
  parent_zone_name  = var.root_url

  deployment_principal_arns = {
    (var.deployment_user) = [""]
  }

  # There seems to be a weird issue here where if the acm has not been run by itself, you will
  # get some weird errors here regarding the zone_id. To fix these comment the below two lines
  # out and run terraform apply, then uncomment them and run apply again.
  depends_on          = [module.acm_request_certificate]
  acm_certificate_arn = module.acm_request_certificate.arn

}

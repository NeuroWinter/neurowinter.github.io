terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.57"
    }
  }

  required_version = "1.0.5"
}

provider "aws" {
  profile = "neurowinter-personal"
  region  = "ap-southeast-2"
}

module "cdn" {
  source = "cloudposse/cloudfront-s3-cdn/aws"
  # Documentation: https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn/blob/master/README.md
  # Cloud Posse recommends pinning every module to a specific version
  version = "0.75.0"

  namespace                           = "NeuroWinter"
  stage                               = "prod"
  name                                = "personal-site"
  aliases                             = var.subdomains
  dns_alias_enabled                   = true
  parent_zone_name                    = var.root_url
  cloudfront_access_logging_enabled   = true
  cloudfront_access_log_create_bucket = true

  deployment_principal_arns = {
    (var.deployment_user) = [""]
  }

  # There seems to be a weird issue here where if the acm has not been run by itself, you will
  # get some weird errors here regarding the zone_id. To fix these comment the below two lines
  # out and run terraform apply, then uncomment them and run apply again.
  acm_certificate_arn = "arn:aws:acm:us-east-1:058786660650:certificate/ccff615f-d1aa-4e24-aa3b-11e28324dc49"

}

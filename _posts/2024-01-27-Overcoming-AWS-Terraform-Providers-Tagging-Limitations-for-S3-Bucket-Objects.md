---
layout: post
category: Terraform
title: Overcoming AWS Terraform Provider's Tagging Limitations for S3 Bucket Objects
description: Overcoming AWS Terraform's S3 tagging limits: practical solutions for efficient cloud management.
---

Tagging in Terraform gives us a very useful tool for managing our infrastructure. It allows us to filter sort, and report on a range of different things, but it also gives our console users some important information. I often use a lot of tags for my resources, these are normally set up when I define my provider, here is such an example:

`(infra/main.tf)`
```yaml
provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Name = "S3 Object Tags Example"
      app-id = "foobar"
      app-role = "example"
      app-purpose = "example"
      cost-center = "blog"
      business-unit = "blog"
      automation-exclude = "true"
      owner = "NeuroWinter"
      project = "blog examples"
      environment = "production"
      terraform = "true"
    }
  }
}
```

These are the tags that I will normally use, I have taken a few of them from an amazing article by [Jirawat Uttayaya](https://engineering.deptagency.com/author/jirawat) on the Dept blog called [Best Practices for Terraform AWS Tags](https://engineering.deptagency.com/best-practices-for-terraform-aws-tags). These will give me more than enough information when I am just browsing around my own resources in the AWS console, and will let me have good granular reporting in my AWS Billing.  Just a note here, these are just example tags, and would be filled out differently on a real deployment.

Now here is the kicker, this will not work when creating S3 Object resources! Here is a very basic example using the above provider:

`(infra/s3.tf)`
```yaml
resource "aws_s3_bucket" "my_bucket" {
  bucket = "neurowintertestbucket"
}

resource "aws_s3_object" "my_bucket_object" {
  bucket = aws_s3_bucket.my_bucket.id
  key    = "my-file.txt"
  source = "./my-file.txt"
  depends_on = [
    aws_s3_bucket.my_bucket
  ]
}
```

The plan looks good, it has listed that it's going to create my bucket, and my object with the correct tags: 

```
...
Plan: 2 to add, 0 to change, 0 to destroy.
```

But when we get to deploying, it's another story:
```
...
│ Error: uploading S3 Object (my-file.txt) to Bucket (neurowintertestbucket): operation error S3: PutObject, https response error StatusCode: 400, RequestID: REDACTED, HostID: REDACTED, api error BadRequest: Object tags cannot be greater than 10
│ 
│   with aws_s3_object.my_bucket_object,
│   on s3.tf line 5, in resource "aws_s3_object" "my_bucket_object":
│    5: resource "aws_s3_object" "my_bucket_object" {
```

Now this is due to a restriction that AWS has on s3 object tags seen here in the first bullet point, [Categorizing your storage using tags](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-tagging.html). Basically, AWS will not allow us to create an object in S3 with more than 10 tags.

## The solution

There are a few ways to solve this issue, but one is my favourite, you can either create a new provider and give it an alias, or just remove the tags in your provider, and set them at the resource level.

First, I am not a fan of setting tags at a resource level, I feel as though it is just repeating yourself, and clutters up the code base.  But the basic way to do this would be to add the `tags` setting to each of your resources, with what you want to tag each resource, and then removing the `default_tags` section of the provider. This does require making this change on all your resources, which in a large code base can be a bit frustrating.


### Provider Alias

This is my preferred solution, as I feel like it keeps the code base clean and easy to read, without cluttering up where your resources are defined. Though, I would always recommend adding a comment when you define this new provider stating why you are doing so. 

Here is an example of a `main.tf` file with two AWS providers:

`infra/main.tf`
```yaml
# This is the main provider, which will be used by default.
# It will automatically apply all the listed tags to our
# resouces.
provider "aws" {
  region = "us-east-1"
  profile = "neurowinter-terraform"
  default_tags {
    tags = {
      Name = "S3 Object Tags Example"
      app-id = "foobar"
      app-role = "example"
      app-purpose = "example"
      cost-center = "blog"
      business-unit = "blog"
      automation-exclude = "true"
      owner = "NeuroWinter"
      project = "blog examples"
      environment = "production"
      terraform = "true"
    }
  }
}

# Creating a new provider with no tags. This provider will
# be used for the S3 object, due to the limitation of a
# maximum of 10 tags on an object.
provider "aws" {
  alias = "noTags"
  region = "us-east-1"
  profile = "neurowinter-terraform"
}
```

Now all we need to do is update our `aws_s3_object` resource to use this new provider:
`infra/s3.tf`
```yaml
resource "aws_s3_bucket" "my_bucket" {
  bucket = "neurowintertestbucket"
}

resource "aws_s3_object" "my_bucket_object" {
  # Here we are telling the resource to use the noTags
  # provider due to S3 object limitation of only allowing
  # 10 tags.
  provider = aws.noTags
  bucket = aws_s3_bucket.my_bucket.id
  key    = "my-file.txt"
  source = "./my-file.txt"
  depends_on = [
    aws_s3_bucket.my_bucket
  ]
}
```


Now it works perfectly!
```
aws_s3_object.my_bucket_object: Creating...
aws_s3_object.my_bucket_object: Creation complete after 1s [id=my-file.txt]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

## Conclusion

I came across this issue while trying to write some Terraform code to deploy an AWS Lambda from an S3 bucket, it ended up setting me back a little bit as I had never encountered this before. 

These little setbacks are all too common, and I shudder to think about the total hours others like me have spent trying to find the solution.

Here is hoping that this acts as a resource for you so that you don't need to spend who knows how long goggling around for the answer. But remember, it is the dedication to learning that makes our jobs so fun! 

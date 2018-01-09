provider "aws" {
  region = "us-west-2"
}

resource "aws_route53_delegation_set" "main" {
  reference_name = "Route53"
}

resource "aws_route53_zone" "primary_group_1" {
  count = "${length(var.domain_group_1)}"
  name = "${element(var.domain_group_1, count.index)}"
  delegation_set_id = "${aws_route53_delegation_set.main.id}"
}

resource "aws_route53_zone" "primary_group_2" {
  count = "${length(var.domain_group_2)}"
  name = "${element(var.domain_group_2, count.index)}"
  delegation_set_id = "${aws_route53_delegation_set.main.id}"
}

resource "aws_route53_record" "www_group_1" {
  count = "${aws_route53_zone.primary_group_1.count}"
  zone_id =  "${element(aws_route53_zone.primary_group_1.*.zone_id, count.index)}"
  name    = "www"
  type    = "CNAME"
  ttl     = "300"
  records = ["${element(aws_route53_zone.primary_group_1.*.name, count.index)}"]
}

resource "aws_route53_record" "www_group_2" {
  count = "${aws_route53_zone.primary_group_2.count}"
  zone_id =  "${element(aws_route53_zone.primary_group_2.*.zone_id, count.index)}"
  name    = "www"
  type    = "CNAME"
  ttl     = "300"
  records = ["${element(aws_route53_zone.primary_group_2.*.name, count.index)}"]
}


resource "aws_s3_bucket" "website_bucket" {
  count = "${length(var.domain_names)}"
  bucket = "${element(var.domain_names, count.index)}"

  website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

resource "aws_s3_bucket_policy" "website_bucket" {
  count = "${length(var.domain_names)}"
  bucket = "${element(var.domain_names, count.index)}"

  policy =<<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
        },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${element(var.domain_names, count.index)}/*",
      "Condition": {
         "StringEquals": {
           "aws:UserAgent": "some secret"}
      }
    }
  ]
}
POLICY
}


resource "aws_cloudfront_distribution" "website_cdn_1" {
  lifecycle {
    create_before_destroy = true
    # ignore_changes = ["*"]
  }
  enabled = true
    count = "${length(var.domain_group_1)}"

  "origin" {
    origin_id = "origin-bucket-${element(var.domain_group_1, count.index)}"
    domain_name = "${element(var.domain_group_1, count.index)}.s3-website-us-west-2.amazonaws.com"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1"]
    }

    custom_header {
      name  = "User-Agent"
      value = "some secret"
    }
  }

  default_root_object = "index.html"

  aliases = ["${element(var.domain_group_1, count.index)}", "www.${element(var.domain_group_1, count.index)}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-bucket-${element(var.domain_group_1, count.index)}"
    min_ttl = "0"
    default_ttl = "300"
    max_ttl = "1200"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  "restrictions" {
    "geo_restriction" {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
    acm_certificate_arn = "arn:aws:acm:us-east-1:111111111111:certificate/aabbccdd-eeff-0011-2233-445566778899" #REPLACE THIS WITH YOUR ARN

  }

}

resource "aws_cloudfront_distribution" "website_cdn_2" {
  lifecycle {
    create_before_destroy = true
    # ignore_changes = ["*"]
  }
  enabled = true
  count = "${length(var.domain_group_2)}"

  "origin" {
    origin_id = "origin-bucket-${element(var.domain_group_2, count.index)}"
    domain_name = "${element(var.domain_group_2, count.index)}.s3-website-us-west-2.amazonaws.com"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["TLSv1"]
    }

    custom_header {
      name  = "User-Agent"
      value = "some secret"
    }
  }

  default_root_object = "index.html"

  aliases = ["${element(var.domain_group_2, count.index)}", "www.${element(var.domain_group_2, count.index)}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "origin-bucket-${element(var.domain_group_2, count.index)}"
    min_ttl = "0"
    default_ttl = "300"
    max_ttl = "1200"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  "restrictions" {
    "geo_restriction" {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1"
    acm_certificate_arn = "arn:aws:acm:us-east-1:111111111111:certificate/aabbccdd-eeff-0011-2233-445566778899" #REPLACE THIS WITH YOUR ARN

  }
}

resource "aws_route53_record" "apex_group_1" {
  count = "${aws_route53_zone.primary_group_1.count}"
  zone_id = "${element(aws_route53_zone.primary_group_1.*.zone_id, count.index)}"
  name = "${element(var.domain_group_1, count.index)}"
  type    = "A"

  alias {
    name                   = "${element(aws_cloudfront_distribution.website_cdn_1.*.domain_name, count.index)}"
    zone_id                = "${element(aws_cloudfront_distribution.website_cdn_1.*.hosted_zone_id, count.index)}"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "apex_group_2" {
  count = "${aws_route53_zone.primary_group_2.count}"
  zone_id = "${element(aws_route53_zone.primary_group_2.*.zone_id, count.index)}"
  name = "${element(var.domain_group_2, count.index)}"
  type    = "A"

  alias {
    name                   = "${element(aws_cloudfront_distribution.website_cdn_2.*.domain_name, count.index)}"
    zone_id                = "${element(aws_cloudfront_distribution.website_cdn_2.*.hosted_zone_id, count.index)}"
    evaluate_target_health = false
  }
}

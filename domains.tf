variable "domain_names" {
  description =  "Create domains for all of our static sites"
  type = "list"
  default = [""]
}

variable "domain_group_1" {
  description = "Need to split the domains up into multiple groups as AWS ACM can only provision a SAN cert for 100 aliases"
  type = "list"
  default = [""]
}

variable "domain_group_2" {
  description = "Need to split the domains up into multiple groups as AWS ACM can only provision a SAN cert for 100 aliases"
  type = "list"
  default = [""]
}

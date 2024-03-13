variable "region" {
  type = string
}
variable "vpc_cidr" {
  type = string
}
variable "subnet_info" {
  type=map(string)
}
variable "bucketName" {
  type = string
}
variable "object_path" {
  type = string
}
variable "object_name_in_s3" {
  type = string
}
variable "IAM_role_name" {
  type = string
}
variable "keypair" {
  type=string 
}
variable "pub_key" {
  type = string
}
variable "instance_ami" {
  type = string
}
variable "instance_type" {
  type = string
}
variable "default_text" {
  type = string
}
region = "us-east-1"
vpc_cidr = "10.1.0.0/16"
subnet_info = {
  name="subnet01"
  az = "us-east-1b"
  cidr = "10.1.1.0/24"
  public_ip = true
}

bucketName = "venkyksjdld7r8378"
object_path = "" # give the path of the object to upload in s3 bucket
object_name_in_s3 = "" # give a name to store the object in bucket with
IAM_role_name = "ec2_role"
keypair = "terraform"
pub_key = "terraform.pub"
instance_ami = "ami-07d9b9ddc6cd8dd30"
instance_type = "t2.micro"
default_text = "give the text to see on nginx webpage"
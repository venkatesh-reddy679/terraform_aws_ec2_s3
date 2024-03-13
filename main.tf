

# Configure the AWS Provider
#authenticate the environment using aws cli to avoid storing of access keys physically
provider "aws" {
  region = var.region
}

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name="vpc01"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name="ig01"
  }
}
resource "aws_internet_gateway_attachment" "ig_vpc_attachment" {
  internet_gateway_id = aws_internet_gateway.internet_gateway.id
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet" {
  vpc_id = aws_vpc.vpc.id
  availability_zone = lookup(var.subnet_info,"az","us-east-1a")
  cidr_block = lookup(var.subnet_info,"cidr","no cidr provided")
  map_public_ip_on_launch = lookup(var.subnet_info,"public_ip","false")
  tags = {
    Name = lookup(var.subnet_info,"name","subnet1")
  }
}

#creating a public route table
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block=aws_vpc.vpc.cidr_block
    gateway_id="local"
  }
 route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
 }
}
 
resource "aws_route_table_association" "rt_association" {
 subnet_id = aws_subnet.subnet.id
 route_table_id = aws_route_table.pub_rt.id 
}

#creating an s3 bucket
resource "aws_s3_bucket" "bucket1" {
  bucket = var.bucketName
  force_destroy = true
}
resource "aws_s3_bucket_ownership_controls" "object_ownership" {
  bucket = aws_s3_bucket.bucket1.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access" {
  bucket = aws_s3_bucket.bucket1.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.object_ownership,
    aws_s3_bucket_public_access_block.bucket_public_access,
  ]

  bucket = aws_s3_bucket.bucket1.id
  acl    = "public-read"
}

#uploading an object to s3 bucket
resource "aws_s3_object" "object" {
  acl = "public-read"
  bucket = aws_s3_bucket.bucket1.bucket
  key    = var.object_name_in_s3
  source = var.object_path
  force_destroy = true
}
# creating an IAM role for ec2 instance to access object in s3 bucket
resource "aws_iam_role" "ec2_s3_role" {
  name = var.IAM_role_name
  assume_role_policy = jsonencode({ # assume role policy grant the entity the required permissions to assume this role
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  inline_policy { # this policy will be inbuilt to this role, not shared to any other role. 
    name = "my_inline_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["s3:GetObject"]
          Effect   = "Allow"
          Resource = [
				"arn:aws:s3:::${aws_s3_bucket.bucket1.bucket}/${aws_s3_object.object.key}"
			]
        },
      ]
    })
  }
  managed_policy_arns = [] # define the set of aws managetd policy arns if needed to use or create a custome managed policy
}

#creatins a security group for ec2 instance
resource "aws_security_group" "sg01" {
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    to_port = 80
    protocol = "tcp"
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "TCP"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "-1"
    from_port = 0
    to_port = 0
  }
}

#providnig the created key-pair to aws
resource "aws_key_pair" "key" {
  key_name = var.keypair
  public_key = file(var.pub_key)
}

#creating an iam_instance_profile to assiate IAM service role to ec2 instance
resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = aws_iam_role.ec2_s3_role.name
}

#creating an ec2 instace that assume the above created role
resource "aws_instance" "instance1" {
  ami = var.instance_ami
  instance_type = var.instance_type
  subnet_id = aws_subnet.subnet.id
  key_name = var.keypair
  security_groups = [aws_security_group.sg01.id]
  iam_instance_profile = aws_iam_instance_profile.test_profile.name
  user_data = <<-EOF
  #! /bin/bash
  sudo apt update
  sudo apt install nginx -y
  cat <<eof | sudo tee /var/www/html/index.html
  <html>
  <head>
  <p>${var.default_text}</p>
  </head>
  <body>
  <p>clink on the<a href="https:${aws_s3_bucket.bucket1.bucket}.s3.amazonaws.com/${aws_s3_object.object.key}">link to download the document</a></p>
  </body>
  </html>
  eof
  sudo systemctl restart nginx
  EOF
       
  provisioner "local-exec" {
    command = "echo public IP of instance: ${self.public_ip}"
  }
}
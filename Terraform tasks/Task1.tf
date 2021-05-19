provider "aws" {
  region                  = "ap-south-1"
  profile                 = "default"
}

resource "aws_vpc" "vpc" {
  cidr_block       = "192.168.0.0/16"

  tags = {
    Name = "vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.vpc.id}"
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private_subnet"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name = "internet_gateway"
  }
}

resource "aws_route_table" "internet_gateway_routing_table" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }

  tags = {
    Name = "internet_gateway_routing_table"
  }
}

resource "aws_route_table_association" "associating_routetable_publicsubnet" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.internet_gateway_routing_table.id
}

resource "tls_private_key" "terraform_key" {
  algorithm  = "RSA"
  rsa_bits = 4096
}

resource "local_file" "private_key" {
	content = tls_private_key.terraform_key.private_key_pem
	filename = "terraform_key.pem"
	file_permission = 0400
}

resource "aws_key_pair" "terraform_key" {
	key_name = "terraform_key"
	public_key = tls_private_key.terraform_key.public_key_openssh
	tags = {
	Name = "terraform_key"
  }
}

resource "aws_security_group" "ssh-http" {
  name        = "ssh-http"
  description = "allow ssh and http traffic"
  vpc_id      = aws_vpc.vpc.id
  ingress {
     from_port   = 22
     to_port     = 22
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
     from_port   = 80
     to_port     = 80
     protocol   = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
  egress {
     from_port       = 0
     to_port         = 0
     protocol        = "-1"
     cidr_blocks     = ["0.0.0.0/0"]
    }
}

resource "aws_instance" "os" {
  ami           = "ami-010aff33ed5991201"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.ssh-http.id}"]
  key_name = aws_key_pair.terraform_key.key_name
  subnet_id = aws_subnet.public_subnet.id

  tags = {
    Name = "First TF OS"
  }
}

resource "aws_ebs_volume" "storage" {
  availability_zone = aws_instance.os.availability_zone
  size              = 10

  tags = {
    Name = "First TF storage"
  }
}

resource "aws_volume_attachment" "storage_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.storage.id
  instance_id = aws_instance.os.id
  force_detach = true
}
provider "aws" {
  region = "ap-south-1"
  profile = "default"
}

resource "aws_vpc" "terraform_vpc" {
  cidr_block       = "192.168.0.0/16"

  tags = {
    Name = "terraform_vpc"
  }
}

resource "aws_subnet" "terraform_vpc_public_subnet" {
  vpc_id     = "${aws_vpc.terraform_vpc.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform_vpc_public_subnet"
  }
}

resource "aws_internet_gateway" "terraform_vpc_internet_gateway" {
  vpc_id = "${aws_vpc.terraform_vpc.id}"

  tags = {
    Name = "terraform_vpc_internet_gateway"
  }
}

resource "aws_route_table" "terraform_internet_gateway_routing_table" {
  vpc_id = "${aws_vpc.terraform_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.terraform_vpc_internet_gateway.id}"
  }

  tags = {
    Name = "terraform_internet_gateway_routing_table"
  }
}

resource "aws_route_table_association" "terraform_associating_routetable_publicsubnet" {
  subnet_id      = aws_subnet.terraform_vpc_public_subnet.id
  route_table_id = aws_route_table.terraform_internet_gateway_routing_table.id
}

resource "aws_eip" "terraform_elastic_ip" {}

//Creating NAT gateway for public subnet
resource "aws_nat_gateway" "terraform_nat_gateway" {
  allocation_id = "${aws_eip.terraform_elastic_ip.id}"
  subnet_id     = "${aws_subnet.terraform_vpc_public_subnet.id}"

  tags = {
    Name = "terraform_nat_gateway"
  }
}

resource "aws_route_table" "terraform_nat_gateway_routing_table" {
  vpc_id = "${aws_vpc.terraform_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.terraform_nat_gateway.id}"
  }

  tags = {
    Name = "terraform_nat_gateway_routing_table"
  }
}

resource "aws_route_table_association" "terraform_associating_routetable_privatesubnet" {
  subnet_id      = aws_subnet.terraform_vpc_private_subnet.id
  route_table_id = aws_route_table.terraform_nat_gateway_routing_table.id
}

resource "aws_subnet" "terraform_vpc_private_subnet" {
  vpc_id     = "${aws_vpc.terraform_vpc.id}"
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "terraform_vpc_private_subnet"
  }
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

resource "aws_security_group" "terraform_security_group_wordpress_ec2" {
  name        = "terraform_security_group_wordpress_ec2"
  description = "ssh, http"
  vpc_id      = aws_vpc.terraform_vpc.id
  ingress {
	description = "http"
	from_port   = 80
	to_port     = 80
	protocol    = "tcp"
	cidr_blocks = ["0.0.0.0/0",]
  }
  ingress {
	description = "ssh"
	from_port   = 22
	to_port     = 22
	protocol    = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
	from_port   = 0
	to_port     = 0
	protocol    = "-1"
	cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
	Name = "terraform_security_group_wordpress_ec2"
  }
}

resource "aws_instance" "terraform_wordpress_ec2instance" {
	ami = "ami-08706cb5f68222d09"
	instance_type = "t2.micro"
	key_name = aws_key_pair.terraform_key.key_name
	vpc_security_group_ids  = ["${aws_security_group.terraform_security_group_wordpress_ec2.id}"]
	subnet_id = aws_subnet.terraform_vpc_public_subnet.id
	tags = {
	Name = "terraform_wordpress_ec2instance"
  }
}

resource "aws_security_group" "terraform_security_group_mysql_ec2" {
  name        = "terraform_security_group_mysql_ec2"
  description = "ssh, tcp"
  vpc_id      = aws_vpc.terraform_vpc.id
  ingress {
	description = "tcp"
	from_port   = 3306
	to_port     = 3306
	protocol    = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
	description = "ssh"
	from_port   = 22
	to_port     = 22
	protocol    = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
	from_port   = 0
	to_port     = 0
	protocol    = "-1"
	cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
	Name = "terraform_security_group_mysql_ec2"
  }
}

resource "aws_instance" "terraform_mysql_ec2instance" {
	ami = "ami-08706cb5f68222d09"
	instance_type = "t2.micro"
	key_name = aws_key_pair.terraform_key.key_name
	vpc_security_group_ids  = ["${aws_security_group.terraform_security_group_wordpress_ec2.id}"]
	subnet_id = aws_subnet.terraform_vpc_private_subnet.id
	tags = {
	Name = "terraform_mysql_ec2instance"
  }
}
provider "aws" {
  region                  = "ap-south-1"
  profile                 = "default"
}

resource "aws_security_group" "ssh-http" {
  name        = "ssh-http"
  description = "allow ssh and http traffic"
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
  security_groups = ["${aws_security_group.ssh-http.name}"]
  key_name = "tf_key"

  tags = {
    Name = "First TF OS"
  }
}

resource "null_resource" "nr0" {
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/devesh.sharma/Downloads/tf_key.pem")
    host     = aws_instance.os.public_ip
  }

  provisioner "remote-exec" {
    inline = [
    "sudo yum install httpd -y",
    "sudo yum install php -y",
    "sudo systemctl enable httpd",
    "sudo systemctl start httpd"
	]
  }
}

resource "aws_ebs_volume" "st" {
  availability_zone = aws_instance.os.availability_zone
  size              = 10

  tags = {
    Name = "First TF storage"
  }
}

resource "aws_volume_attachment" "st_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.st.id
  instance_id = aws_instance.os.id
  force_detach = true
}

resource "null_resource" "nr1" {
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/devesh.sharma/Downloads/tf_key.pem")
    host     = aws_instance.os.public_ip
  }

  provisioner "remote-exec" {
    inline = [
    "sudo mkfs.ext4 /dev/sdh",
    "sudo mount /dev/sdh /var/www/html",
    "sudo yum install git -y",
    "sudo git clone https://github.com/vimallinuxworld13/gitphptest.git /var/www/html"
    ]
  }
}

resource "null_resource" "nr2" {
  provisioner "local-exec" {
    command = "chrome http://${aws_instance.os.public_ip}/"
  }
}
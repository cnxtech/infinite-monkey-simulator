
variable "private_key" {}

provider "aws" {
  region     = "us-west-2"
}

resource "aws_instance" "monkey" {
  ami           = "ami-03c652d3a09856345"
  instance_type = "t1.micro"
  iam_instance_profile = "monkey"
  key_name      = "monkey"
  tags = {
    Name = "monkey"
  }

  connection "ssh" {
    user = "ec2-user"
    private_key = "${file(var.private_key)}"
  }

  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/bin",
      "sudo yum -y install git ruby ruby-devel gcc gcc-c++",
      "sudo gem install sys-proctable",
      "git clone https://github.com/rstms/infinite-monkey-simulator"
    ]
  }
}

output "ip" {
  value = "${aws_instance.monkey.public_ip}"
}

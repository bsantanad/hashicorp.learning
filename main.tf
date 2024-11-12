provider "aws" {
    region = "us-east-2"
}

variable "server_port" {
    description = "the port the server will use for http requests"
    type = number
    default = 8080
}

output "public_ip" {
    value = aws_instance.example.public_ip
    description = "the public ip address of the web server"
}

resource "aws_instance" "example" {
    # amazon machine image to run on the ec2 instance, this is an ubuntu 20.04
    ami = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"

    # use terraform expressions to refer to the security rule we want to follow
    vpc_security_group_ids = [aws_security_group.instance.id]

    # we would usually create an AMI for this with a real web app, using rails
    # or smth, but this is just a simple example.
    user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

    user_data_replace_on_change = true

    tags = {
        Name = "terraform-example"
    }
}

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


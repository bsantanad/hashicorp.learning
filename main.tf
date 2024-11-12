provider "aws" {
    region = "us-east-2"
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
              nohup busybox httpd -f -p 8080 &
              EOF

    user_data_replace_on_change = true

    tags = {
        Name = "terraform-example"
    }
}

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


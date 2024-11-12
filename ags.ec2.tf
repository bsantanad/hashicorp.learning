provider "aws" {
    region = "us-east-2"
}

variable "server_port" {
    description = "the port the server will use for http requests"
    type = number
    default = 8080
}

# expose server_port (default 8080) on ec2 instance.
resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_launch_template" "example" {
    name_prefix   = "example-"
    image_id = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"

    vpc_security_group_ids = [aws_security_group.instance.id]

    user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
    )
}


resource "aws_autoscaling_group" "example" {

    launch_template {
        id = aws_launch_template.example.id
        version = "$Latest"
    }

    # which subnet should ags use? we get this from the data sources.
    vpc_zone_identifier = data.aws_subnets.default.ids

    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }

}

# we need to tell the ags which subnet to use, this data source  will return
# the the default vpc in our aws account, which then we will use to query for
# the subnets.
data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

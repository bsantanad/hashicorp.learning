provider "aws" {
    region = "us-east-2"
}

variable "server_port" {
    description = "the port the server will use for http requests"
    type = number
    default = 8080
}

output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "dns of the load balancer"
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

    # which subnet should asg use? we get this from the data sources.
    vpc_zone_identifier = data.aws_subnets.default.ids


    # add load balancing target group
    target_group_arns = [aws_lb_target_group.asg.arn]

    # this ELB thing, is telling aws to use the healthcheck of the target
    # group, which is more robust that the one that comes by default.
    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    tag {
        key = "Name"
        value = "terraform-asg-example"
        propagate_at_launch = true
    }

}

# we need to tell the asg which subnet to use, this data source  will return
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

##
# load balancing part
resource "aws_lb" "example" {
    name = "terraform-asg-example"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids

    # define a security group similar to what we did in the ec2 template
    security_groups = [aws_security_group.alb.id]
}


# configure the aws_lb to listen to port 80 and use http
resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = 80
    protocol = "HTTP"

    # send 404 to requests that do not match any listener rules.
    default_action {
        type = "fixed-response"

        # by default, return just a 404
        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code  = 404

        }
    }
}

# we need create a security group for the load balancing objects, since they do
# not allow any traffic by default.
resource "aws_security_group" "alb" {
    name = "terraform-example-alb"

    # inbound http requests
    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # outbound http requests
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1" # -1 is a wild card that means all protocols.
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Health checks your instances by periodically sending an HTTP request to each
# ec2. If one becomes unhealthy will stop sending the traffic to it.
#
# Ojito, we are not defining which ec2 instances to send requests to
# here. That will be done in aws_autoscaling_group using the parameter
# aws_lb_target_group_attachment.
resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    # match any path...
    condition {
        path_pattern {
            values = ["*"]
        }
    }

    # ...and send it to our asg group
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}

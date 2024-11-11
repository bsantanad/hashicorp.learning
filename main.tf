provider "aws" {
    region = "us-east-2"
}

resource "aws_instance" "example" {
    # amazon machine image to run on the ec2 instance, this is an ubuntu 20.04
    ami = "ami-0fb653ca2d3203ac1"
    instance_type = "t2.micro"

    tags = {
        Name = "terraform-example"
    }
}

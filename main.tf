resource "aws_vpc" "main" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"
}

#Creation of subnets for the VPC
resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_2"
  }
}

#creat internet_gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

}

resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
  
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "my_sg" {
    name_prefix = "web-sg"
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "web_sg"
  }
}


resource "aws_vpc_security_group_ingress_rule" "ingress_rule1" {
  security_group_id = aws_security_group.my_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
  description = "Allow SSH in VPC"
}

resource "aws_vpc_security_group_ingress_rule" "ingress_rule2" {
  security_group_id = aws_security_group.my_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
  description = "TLS in VPC "
}



resource "aws_vpc_security_group_egress_rule" "outbound_rule" {
  security_group_id = aws_security_group.my_sg.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
  description = "TLS from VPC"
}

#creating S3 bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "nitya-bucket"
}

resource "aws_instance" "instance_1" {
  ami                     = "ami-04b4f1a9cf54c11d0"
  instance_type           = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  subnet_id = aws_subnet.subnet_1.id
  user_data = base64encode(file("userdata.sh"))
}

resource "aws_instance" "instance_2" {
  ami                     = "ami-04b4f1a9cf54c11d0"
  instance_type           = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  subnet_id = aws_subnet.subnet_2.id
  user_data = base64encode(file("userdata2.sh"))
}

resource "aws_lb" "ALB" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_sg.id]
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tags = {
    Name = "web"
  }

}

resource "aws_lb_target_group" "alb_TG" {
    name = "my-TG"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main.id

    health_check {
      path = "/"
      port = "traffic-port"
    }
}

resource "aws_alb_target_group_attachment" "attach1" {
    target_group_arn = aws_lb_target_group.alb_TG.arn
    target_id = aws_instance.instance_1.id
    port = 80
  
}

resource "aws_alb_target_group_attachment" "attach2" {
    target_group_arn = aws_lb_target_group.alb_TG.arn
    target_id = aws_instance.instance_2.id
    port = 80
  
}

resource "aws_lb_listener" "lb_listener" {
    load_balancer_arn = aws_lb.ALB.arn
    protocol = "HTTP"
    port = 80

    default_action {
      target_group_arn = aws_lb_target_group.alb_TG.arn
      type = "forward"
    }

}

output "loadbalancerdns" {
    value = aws_lb.ALB.dns_name
}
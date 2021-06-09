provider "aws" {
    region  = "us-east-2"
}
# variable for subnet
variable "pubsubnet" {
    type = list
    default = ["10.0.0.0/26" , "10.0.0.64/26"]
}
# variable for subnet
variable "prisubnet" {
    type = list
    default = ["10.0.0.128/26" , "10.0.0.192/26"]
}
# variable for Availability Zone
variable "AZS" {
    type = list
    default = ["us-east-2c" , "us-east-2b"]
}
# variable for instance type
variable "instance_type" {
    default = "t2.micro"
}
variable "aws_region" {
    default = "us-east-2"
}
variable "instance_count" {
    default = "2"
}
# Creating VPC
resource "aws_vpc" "Newvpc" {
    cidr_block = "10.0.0.0/24"
    enable_dns_hostnames = "false"
    enable_dns_support = true
    tags = {
      Name = "terravpc"
    }
  }
# creating private and public subnet
resource "aws_subnet" "pubsub" {
    count = length(var.pubsubnet)
    vpc_id = aws_vpc.Newvpc.id
    cidr_block = element(var.pubsubnet,count.index)
    availability_zone = element(var.AZS,count.index)
    tags = {
      "Name" = "Subnet-${count.index+1}"
    }
}
resource "aws_subnet" "prisub" {
    count = length(var.prisubnet)
    vpc_id = aws_vpc.Newvpc.id
    cidr_block = element(var.prisubnet,count.index)
    availability_zone = element(var.AZS,count.index)
    tags = {
      "Name" = "Subnetpri-${count.index+1}"
    }
}
# Creating Internet gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.Newvpc.id
    tags = {
      Name = "newigw"
    }
}
# creating EIP
resource "aws_eip" "eip" {  
}
#Creating NAT Gateway
resource "aws_nat_gateway" "NAT_GW" {
    allocation_id = aws_eip.eip.id
    subnet_id = "aws_subnet.pubsub[*].id" 
    tags = {
      "Name" = "NAT_GW"
    } 
}
# Creating Route tables
resource "aws_route_table" "pubroute" {
    vpc_id = aws_vpc.Newvpc.id
    tags = {
      "Name" = "Public_RT"
    }
}
resource "aws_route_table" "priroute" {
    vpc_id = aws_vpc.Newvpc.id
    tags = {
      "Name" = "Private_RT"
    }
}
# Associating Internetgateway to public route table
resource "aws_route_table_association" "associateigw" {
    route_table_id = aws_route_table.pubroute.id
    count = length(var.pubsubnet)
    subnet_id = element(aws_subnet.pubsub.*.id,count.index)
}
# Associating subnet to private route table
resource "aws_route_table_association" "associatesub" {
    route_table_id = aws_route_table.priroute.id
    count = length(var.prisubnet)
    subnet_id = element(aws_subnet.prisub.*.id,count.index)
}
# Creating Security Group
resource "aws_security_group" "newsg" {
  name        = "newsg"
  description = "overallsg"
  vpc_id      = aws_vpc.Newvpc.id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  
  }
    ingress {
    description      = "HTTPs"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] 
  }
    ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] 
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
    egress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  } 
  tags = {
    Name = "AlloverSG"
  }
}
# Creating Security Group for LB
resource "aws_security_group" "lbsg" {
  name        = "lbsg"
  description = "loadbalancersg"
  vpc_id      = aws_vpc.Newvpc.id
  ingress {
    description      = "HTTP"
    from_port        = 0
    to_port          = 0
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  
  }
  tags = {
    Name = "LBSG"
  }
}
# creating Ec2 instances in public subnet
resource "aws_instance" "Pub_instances" {
  count = var.instance_count
  ami = "ami-077e31c4939f6a2f3"
  instance_type = var.instance_type
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.newsg.id}"]
  subnet_id = element(aws_subnet.pubsub.*.id,count.index)
  key_name = "Design_Key"
  user_data = "touch /home/ec2-user/abc"
  tags = {
    Name  = "PubTerraform-${count.index + 1}"
  }
}
# creating Ec2 instances in private subnet
resource "aws_instance" "webserver" {
  count = var.instance_count
  ami = "ami-077e31c4939f6a2f3"
  instance_type = var.instance_type
  vpc_security_group_ids = ["${aws_security_group.newsg.id}"]
  subnet_id = element(aws_subnet.prisub.*.id,count.index)
  key_name = "Design_Key"
  user_data = <<-EOF
            #! /bin/bash
            sudo yum update -y
            sudo yum install -y httpd.x86_64
            sudo systemctl start httpd.service
            systemctl enable httpd.service
            sudo echo "<h1>hey this webserver from $(hostname -f)</h1>" >> /var/www/html/index.html
  EOF                     
  tags = {
    Name  = "Terraform-${count.index + 1}"
  }
}
# Creating Target Group for load balancer
resource "aws_lb_target_group" "LB_TargetGroup" {
    name = "TGLB"
    target_type = "instance"
    protocol = "HTTP"
    port = 80
    vpc_id = aws_vpc.Newvpc.id
    tags = {
      "Name" = "TGLB"
    }
}
# Attaching instances in Target Group
resource "aws_lb_target_group_attachment" "addingInstances" {
    count = length(aws_instance.webserver)
    target_group_arn = aws_lb_target_group.LB_TargetGroup.arn
    target_id = aws_instance.webserver[count.index].id
}
# creating Application Load balancer
resource "aws_alb" "ApplicationLB" {
    name = "AppLB"
    subnets = aws_subnet.pubsub.*.id
    security_groups = ["${aws_security_group.lbsg.id}"]
}
# Creating alb listener
resource "aws_alb_listener" "applis" {
    port = 80
    protocol = "HTTP"
    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.LB_TargetGroup.arn
    }
    load_balancer_arn = aws_alb.ApplicationLB.arn
}
#creating AMI
resource "aws_ami_from_instance" "webserverAMI" {
    name = "webserverAMI"
    source_instance_id = "i-0aec10e2fe9724fa1" 
}
# Creating LC
resource "aws_launch_configuration" "LC_ASG" {
    image_id = aws_ami_from_instance.webserverAMI.id
    instance_type = var.instance_type
}
resource "aws_autoscaling_group" "ASG" {
    name = "ASG"
    launch_configuration = aws_launch_configuration.LC_ASG.id
    availability_zones = ["us-east-2c" , "us-east-2b"]
    max_size = 1
    min_size = 1
    force_delete = true 
    tags = [ {
      key = "Name"
      value = "Web"
    } ]
}

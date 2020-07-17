#CONFIGURED AWS#

provider "aws" {
  region     = "ap-south-1"
}

#CREATED VPC#
resource "aws_vpc" "myvpc" {
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  
  tags = {
    Name = "main-vpc"
  }
}


#CREATED ONE PUBLIC SUBNET  &  ONE PVT. SUBNET#

resource "aws_subnet" "subnet1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "192.168.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public-1a"
  }
}
resource "aws_subnet" "subnet2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private-1b"
  }
}

#CREATED A PUBLIC FACING INTERNET GATEWAY#

resource "aws_internet_gateway" "int-gat" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = "my-int-gat"
  } 
}


##CREATED A ROUTE TABLE FOR INTERNET GATEWAY AND ADDED ROUTE SO THAT EVERYONE CAN CONNECT TO THE INSTANCE USING INTERNET GATEWAY##

resource "aws_route_table" "route-tab" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int-gat.id
  }
  
  tags = {
    Name = "route-public"
  }
}
resource "aws_route_table_association" "subnet1-asso" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route-tab.id
}


##CREATED NAT GATEWAY CONNECT VPC TO INTERNET WORLD & ATTACHED THIS GATEWAY TO VPC IN PUBLIC NETWORK##

##CREATED EIP##

resource "aws_eip" "eip" {
  vpc = true
  depends_on = [ "aws_internet_gateway.int-gat" ]
}


## CREATED NAT GATEWAY ##
resource "aws_nat_gateway" "nat-gat" {
  allocation_id = "${aws_eip.eip.id}"
  subnet_id = aws_subnet.subnet1.id
  depends_on = [ "aws_internet_gateway.int-gat" ]
}


##UPDATED ROUTE TABLE OF PVT. SUBNET TO ACCESS INTERNET USES NAT GATEWAY CREATED IN PUBLIC SUBNET##
resource "aws_route_table" "nat-route-tab" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gat.id
  }
  
  tags = {
    Name = "route-private"
  }
}
resource "aws_route_table_association" "subnet2-asso" {
  subnet_id = aws_subnet.subnet2.id
  route_table_id = aws_route_table.nat-route-tab.id
}

##CREATED  3 SG ALL HAVE SSHi & ONE WITH MYSQL PORT (3306) & OTHER HAVE HTTP PORT (80) ENABLED##
resource "aws_security_group" "allow-ports-wp" {
  name        = "allow-ports-wp"
  description = "Allow http "
  vpc_id      = aws_vpc.myvpc.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "allow-ports-wp"
  }
}
resource "aws_security_group" "allow-ports-mysql" {
  depends_on = [ "aws_security_group.allow-ports-bastion" ]
  name        = "allow-ports-mysql"
  description = "Allow mysql"
  vpc_id      = aws_vpc.myvpc.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_security_group.allow-ports-bastion.id] 
  }
ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"    
    cidr_blocks = [aws_security_group.allow-ports-wp]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow-ports-mysql"
  }
}
resource "aws_security_group" "allow-ports-bastion" {
  name        = "allow-ports"
  description = "Allow ssh"
  vpc_id      = aws_vpc.myvpc.id
  
  ingress {
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
    Name = "allow-ports"
  }
}



##LAUNCHED EC2 INSTANCE HAVING WORDPRESS SETUP ALREADY WITH SG ALLOWING PORT 80 SO THAT OUR CLIENT CAN CONNECT TO WORDPRESS SITE ALSO ATTACHED KEY ## 

resource "aws_instance" "wordpress" {
  ami = "ami-0d334eb087b438c4a"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet1.id
  associate_public_ip_address = true
  key_name = "mykey1111"
  vpc_security_group_ids = [aws_security_group.allow-ports-wp.id]
  tags = {
    Name = "wp-os"
  }
}



##LAUNCHED EC2 INSTANCE USED AS OS  ALREADY WITH SG ALLOWING PORT 22 SO THAT OUR OS CAN CONNECT TO OTHER INSTANCES IN SAME VPC ALSO ATTACHED KEY##

resource "aws_instance" "bastion" {
  ami = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet1.id
  associate_public_ip_address = true
  key_name = "mykey1111"
  vpc_security_group_ids = [aws_security_group.allow-ports-bastion.id ]
  tags = {
    Name = "bastion-os"
  }
}









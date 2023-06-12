provider "aws" {
  region     = "us-west-2"
  shared_credentials_files=["/Users/josephbabal/Desktop/credentials"]
  profile="default"
}

resource "aws_key_pair" "cs312" {
  key_name ="cs312"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcbHi3rLqeNzkOwSbd6RNIm31d6/D5lCPQxxkZnWdRT josephbabal@10-249-30-95.wireless.oregonstate.edu"
}

resource "aws_vpc" "minecraft_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "minecraft_subnet"{
  vpc_id     = aws_vpc.minecraft_vpc.id
  availability_zone = "us-west-2a"
  cidr_block = "10.0.0.0/24"
}

resource "aws_internet_gateway" "minecraft_igw" {
  vpc_id = aws_vpc.minecraft_vpc.id
}

resource "aws_route_table" "minecraft_route_table" {
  vpc_id = aws_vpc.minecraft_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minecraft_igw.id
  }
}

resource "aws_route_table_association" "minecraft_route_table_association" {
  subnet_id      = aws_subnet.minecraft_subnet.id
  route_table_id = aws_route_table.minecraft_route_table.id
}


resource "aws_security_group" "minecraft_sg" {
  name        = "minecraft-server-sg"
  description = "Security group for Minecraft server"
  vpc_id = aws_vpc.minecraft_vpc.id

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

resource "aws_instance" "minecraft_server" {
  ami           = "ami-03f65b8614a860c29"
  instance_type = "t2.micro"
  count = "1"
  key_name      =  aws_key_pair.cs312.key_name
  subnet_id     = aws_subnet.minecraft_subnet.id
  vpc_security_group_ids = [aws_security_group.minecraft_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "minecraft-server-final"
  }
}





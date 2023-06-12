# CS-312-final
 this project is to fully automate the provisioning, configuration, and setup of your Minecraft server using the tools discussed in this course: Ansible, Terraform, Pulumi, Docker, Scripting, GitHub Actions, AWS, etc.


# Getting Started
1. Install terraform `brew install terraform`
2. Create one file: `touch main.tf`
3. Create another file called credentials (save the path to that file)
4. Start up AWS Lab, click AWS details and copy the entire cirtificate into the credentials file
5. Create key pair by running `ssh-keygen -t ed25519` in the same directory where you are working. Name it CS-312-final and hit enter 2 times. Two files should have been created. 
    - CS-312-final and CS-312-final.pub
6. Run `terraform init` to initialize the Terraform environment.

# Create Terraform script:
1. Create Provider configuration. In the main.tf file, configure the AWS provider to specify the region and authentication credentials.

    ```
    provider "aws" {
        region     = "us-west-2"
        shared_credentials_files=["file/path/to/credentials/file"]
        profile="default"
    } 
    ```

2. Setup VPC configuration below the provider to keep the server isolated

    ```
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

    ```
3. Create Security Groups below VPC configuration to allow access to  minecraft and port 22
    ```
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
    ```

4. Create Key pair configuration below security group. Copy the contents in the CS-312-final.pub file and use that for the public_key value. This will be used to SSH

    ```
    resource "aws_key_pair" "cs312" {
        key_name ="cs312"
        public_key = "<CS-312-final.pub content>"
    }
    ```

5. Create EC2 instance configuration after all the configuarations. This will allow you to have a public ip address and name the EC2 instance.
    - Depending on the image you use, change the ami and instance_type to the correct values.
    ```
    resource "aws_instance" "minecraft_server" {
        ami           = "ami-your-ami-image"
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
    ```

# Create an Ansible Playbook
1. Create a yml file `touch playbook.yml`
2. Paste this into the playbook.yml file and it will install everything for the minecraft server and enable auto-start
    ```
    - name: Provision Minecraft server
    hosts: all
    become: yes
    tasks:
        - name: Update system packages
        apt:
            update_cache: yes
            upgrade: yes

        - name: Install openjdk 17
        apt:
            name: openjdk-17-jdk-headless
            state: present

        - name: Create Minecraft server directory
        file:
            path: /home/ubuntu/minecraft-server
            state: directory
            owner: ubuntu
            group: ubuntu

        - name: Download Minecraft server
        get_url:
            url: https://piston-data.mojang.com/v1/objects/8f3112a1049751cc472ec13e397eade5336ca7ae/server.jar
            dest: /home/ubuntu/minecraft-server/server.jar

        - name: Set eula.txt file
        copy:
            content: "eula=true"
            dest: /home/ubuntu/minecraft-server/eula.txt

        - name: Create systemd service unit for Minecraft
        copy:
            content: |
            [Unit]
            Description=Minecraft Server
            After=network.target

            [Service]
            User=ubuntu
            WorkingDirectory=/home/ubuntu/minecraft-server
            ExecStart=/usr/bin/java -Xmx1024M -Xms1024M -jar server.jar nogui
            Restart=always
            RestartSec=3

            [Install]
            WantedBy=multi-user.target
            dest: /etc/systemd/system/minecraft.service

        - name: Enable and start the Minecraft service
        systemd:
            name: minecraft
            state: started
            enabled: yes
    ```

# Executing Ansible
1. Create a host file `touch hosts`
2. Paste this into the hosts file. 
    - Notes: 
        - change the public ip addr to the public ip address of your instance. Make sure to use '-' instead of '.'.
        - change ansible_user to the name of your user for your instance

    ```
    [minecraft_server]
    ec2-public-ip-addr.us-west-2.compute.amazonaws.com     ansible_user=ubuntu     ansible_ssh_private_key_file=./CS-312-final
    ```

# Running and connecting to minecraft server
1. Run ` terraform apply` to apply the configurations to create the AWS resource
2. Run `ansible-playbook -i hosts playbook.yml` to execute the Ansible playbook.
3. Once that is done, run `nmap -sV -Pn -p T:25565 <public_ip_addr_of_instance>` to check if server is running and you can connect to it. The status should say open


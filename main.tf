terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.16"
        }
    }
}

provider "aws" {
    region = "eu-central-1"
    access_key = var.aws_acces_key
    secret_key = var.aws_secret_key
    token = var.aws_token
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/new_master_key.pub") 
}

resource "aws_security_group" "nextjs2_sg" {
  name        = "nextjs2-sg"
  description = "Allow inbound traffic for port 80, 443, 22 and 3000"

  # Erlauben von HTTP-Zugriff auf Port 80
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Erlauben von HTTPS-Zugriff auf Port 443
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Erlauben von Zugriff auf Port 3000 (wahrscheinlich für Ihre Next.js-App)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Erlauben von SSH-Zugriff auf Port 22
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Standard-Egress-Regel, um alle ausgehenden Verbindungen zu erlauben
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "nextjs_app" {
  ami           = "ami-065ab11fbd3d0323d" 
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.nextjs2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install nodejs nginx -y
              sudo npm install -g npm@10.2.0
              sudo yum install git -y
              git clone https://github.com/tarasowski/nextjs-todo2.git ~/nextjs-todo2
              cd ~/nextjs-todo2
              npm install
              npm run build
              sudo npm install -g pm2
              pm2 start npm --name "nextjs-todo2" -- run start

              cat <<-EOL | sudo tee /etc/nginx/conf.d/nextjs.conf
              server {
                  listen 80;
                  listen [::]:80;
                  server_name _;
                  location / {
                      proxy_pass http://localhost:3000;
                      proxy_http_version 1.1;
                      proxy_set_header Upgrade \$http_upgrade;
                      proxy_set_header Connection 'upgrade';
                      proxy_set_header Host \$host;
                      proxy_cache_bypass \$http_upgrade;
                  }
              }
              EOL

              sudo systemctl restart nginx
              EOF

  tags = {
    Name = "nextjs-todo5"
  }
}



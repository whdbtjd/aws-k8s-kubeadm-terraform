provider "aws" {
  region = "ap-northeast-2"
}

# 최신 Ubuntu 22.04 AMI 자동 검색
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical 공식 계정

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 보안 그룹 설정
resource "aws_security_group" "k8s_sg" {
  name        = "k8s-lab-sg"
  description = "Security group for K8s cluster"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
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

# 마스터 노드 (온디맨드 + 퍼블릭 IP)
resource "aws_instance" "master" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  key_name                    = "Terraform"
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  associate_public_ip_address = true # SSH 접속을 위한 퍼블릭 IP 부여

  user_data = file("userdata.sh")

  tags = {
    Name = "k8s-master"
  }
}

# 워커 노드 (스팟 인스턴스 2대 + 퍼블릭 IP)
resource "aws_spot_instance_request" "workers" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  key_name                    = "Terraform"
  vpc_security_group_ids      = [aws_security_group.k8s_sg.id]
  associate_public_ip_address = true # SSH 접속을 위한 퍼블릭 IP 부여

  spot_price           = "0.03"
  wait_for_fulfillment = true
  spot_type            = "one-time"

  user_data = file("userdata.sh")

  tags = {
    Name = "k8s-worker-${count.index}"
  }
}

# 생성 완료 후 출력될 IP 정보
output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = aws_spot_instance_request.workers[*].public_ip
}
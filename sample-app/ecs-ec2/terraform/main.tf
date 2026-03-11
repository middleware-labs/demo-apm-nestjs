# Dynamically fetch the latest ECS-optimized Amazon Linux 2 AMI
data "aws_ami" "ecs" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}
# Create a third public subnet in a new AZ for better Spot capacity
resource "aws_subnet" "public3" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true
}

# Associate the third public subnet with the route table
resource "aws_route_table_association" "public3" {
  subnet_id      = aws_subnet.public3.id
  route_table_id = aws_route_table.public.id
}
##########################################
# EC2 Spot Instances for ECS Cluster
##########################################

# IAM Instance Profile for ECS EC2
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole-ec2"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Effect": "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile-ec2"
  role = aws_iam_role.ecs_instance_role.name
}

# Launch Template for EC2 Spot Instances
resource "aws_launch_template" "ecs_spot_lt" {
  name_prefix   = "ecs-spot-"
  image_id      = data.aws_ami.ecs.id
  instance_type = "t3.medium"
  key_name = "ecs-ec2-spot"
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }
  user_data = base64encode(<<EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.nestjs_keval_app_cluster.name} >> /etc/ecs/ecs.config
EOF
  )
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.ecs_sg.id]
  }
  # Spot configuration is handled by the Auto Scaling Group's mixed_instances_policy
}

# Auto Scaling Group for Spot Instances
resource "aws_autoscaling_group" "ecs_spot_asg" {
  name                      = "ecs-spot-asg-ec2"
  min_size                  = 1
  max_size                  = 3
  desired_capacity          = 1
  vpc_zone_identifier       = [aws_subnet.public1.id, aws_subnet.public2.id, aws_subnet.public3.id]
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs_spot_lt.id
        version           = "$Latest"
      }
      override {
        instance_type = "t3.micro"
      }
      override {
        instance_type = "t3.small"
      }
      override {
        instance_type = "t3a.micro"
      }
      override {
        instance_type = "t3a.small"
      }
      override {
        instance_type = "t2.micro"
      }
      override {
        instance_type = "t2.small"
      }
      override {
        instance_type = "m5.large"
      }
      override {
        instance_type = "m5a.large"
      }
    }
    instances_distribution {
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
    }
  }
  tag {
    key                 = "Name"
    value               = "ecs-spot-instance"
    propagate_at_launch = true
  }
  lifecycle {
    create_before_destroy = true
  }
}
provider "aws" {
  region = "us-east-1"
}

###############################
# VPC, Subnets, and Routing
###############################

# Create a new VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create two public subnets in different AZs
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

# Internet Gateway for outbound internet access
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route Table with default route to the Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the public subnets with the route table
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

##########################################
# Security Groups for ALB and ECS Service
##########################################

# Security group for the ALB (allow inbound traffic on port 3000)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow inbound traffic on port 3000"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP traffic on port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for ECS tasks (allow inbound from the ALB on port 3000)
resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow inbound traffic from ALB on port 3000"
  vpc_id      = aws_vpc.main.id

  ingress {
    description       = "Allow ALB traffic on port 3000"
    from_port         = 3000
    to_port           = 3000
    protocol          = "tcp"
    security_groups   = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "Allow SSH from anywhere (for testing)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##########################################
# Application Load Balancer & Listener
##########################################

# Create an ALB in the public subnets
resource "aws_lb" "app_lb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]
}

# Create a target group for your ECS service (target port 3000)
resource "aws_lb_target_group" "app_tg_ec2" {
  name     = "app-tg-ec2"
  port     = 3000
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    port                = "3000"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }
}

# Create a listener on the ALB on port 3000
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 3000
  protocol          = "HTTP"

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app_tg_ec2.arn
    }
}

###############################
# ECS Cluster, Task, and Service
###############################

# Create an ECS Cluster
resource "aws_ecs_cluster" "nestjs_keval_app_cluster" {
  name = "app-cluster"
}

# Create an IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "nestECSTaskExecutionRole-ec2"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }]
  })
}

# Create an IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "nestECSTaskRole-ec2"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }]
  })
}

# Add policy for ECS Execute Command
resource "aws_iam_role_policy" "ecs_execute_command_policy" {
  name = "ecs-execute-command-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Add execute command policy to task execution role
resource "aws_iam_role_policy" "ecs_execute_command_execution_policy" {
  name = "ecs-execute-command-execution-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create an ECS Task Definition for your Nest.js app
resource "aws_ecs_task_definition" "app_task" {
  family                   = "nestjs-app"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name         = "nestjs-app"
      image        = "ghcr.io/middleware-labs/demo-apm-nestjs:local"
      cpu          = 256
      memory       = 1024
      portMappings = [
        {
          containerPort = 3000,
          hostPort      = 3000,
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      essential = true,
      logConfiguration = {
          logDriver = "awsfirelens",
          options = {
              Host = "127.0.0.1",
              Name = "forward",
              Port = "8006"
          }
      },
      environment = [
        {
            name  = "OTEL_BSP_SCHEDULE_DELAY"
            value = "100"
        },
        {
          name  = "MW_API_KEY"
          value = "xxxxxxxxxxxxxxxxxxx"
        },
        {
          name  = "MW_TARGET"
          value = "https://xxxxx.middleware.io:443"
        },
        {
          name  = "MW_SERVICE_NAME"
          value = "nestjs-ecs-fargate-delay"
        },
        {
          name  = "MW_DEBUG"
          value = "false"
        },
        {
          name  = "OTEL_LOG_LEVEL"
          value = "debug"
        }
      ]
    },
   {
        name = "log_router",
        image = "amazon/aws-for-fluent-bit:stable",
        cpu = 128,
        memory = 128,
        portMappings = [],
        essential = true,
        environment = [],
        mountPoints = [],
        volumesFrom = [],
        user = "0",
        firelensConfiguration = {
            type = "fluentbit",
            options = {
                "enable-ecs-log-metadata" = "true"
            }
        }
    }
  ])
}

# Create an ECS Fargate Service and attach it to the ALB target group
resource "aws_ecs_service" "app_service" {
  name            = "nestjs-app-service"
  cluster         = aws_ecs_cluster.nestjs_keval_app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "EC2"
  enable_execute_command = true

    load_balancer {
      target_group_arn = aws_lb_target_group.app_tg_ec2.arn
      container_name   = "nestjs-app"
      container_port   = 3000
    }

  depends_on = [
    aws_lb_listener.app_listener
  ]
}

# Run mw-agent as a daemon on every EC2 instance
resource "aws_ecs_task_definition" "mw_agent_daemon" {
  family                   = "mw-agent-daemon"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "mw-agent"
      image = "ghcr.io/middleware-labs/mw-host-agent:1.16.9991"
      cpu   = 256
      memory = 256
      essential = true
      environment = [
        {
          name  = "MW_API_KEY0"
          value = "mlqrrmzujnkdpwyxjhhtfdbisuwnsrpdrlxd"
        },
        {
          name  = "MW_TARGET0"
          value = "https://sandbox-ovs.middleware.io"
        },
        {
          name  = "MW_API_KEY"
          value = "npanajucwjtcsyqqgnidwbsbobuowldmlsjp"
        },
        {
          name  = "MW_TARGET"
          value = "https://sandbox-bay.middleware.io"
        },
        {
          name  = "MW_OTEL_CONFIG_FILE"
          value = "/etc/mw-agent/otel-config-base.yaml"
        },
        {
          name  = "MW_FETCH_ACCOUNT_OTEL_CONFIG"
          value = "false"
        },
        {
          name  = "ECS_CLUSTER_NAME"
          value = "app-cluster"
        },
         {
          name  = "AWS_REGION"
          value = "us-east-1"
        }
      ]
      mountPoints = [
        {
          containerPath = "/var/run/docker.sock"
          sourceVolume  = "docker_sock"
          readOnly      = false
        },
        {
          containerPath = "/var/lib/docker/containers"
          sourceVolume  = "docker_containers"
          readOnly      = true
        },
        {
          containerPath = "/sys/fs/cgroup"
          sourceVolume  = "cgroup"
          readOnly      = true
        },
        {
          containerPath = "/host/sys/fs/cgroup"
          sourceVolume  = "cgroup_host"
          readOnly      = true
        },
        {
          containerPath = "/rootfs/proc"
          sourceVolume  = "proc"
          readOnly      = true
        },
        {
          containerPath = "/rootfs/var/lib/docker"
          sourceVolume  = "docker_root"
          readOnly      = true
        }
      ]
    }
  ])

  volume {
    name = "docker_sock"
    host_path = "/var/run/docker.sock"
  }
  volume {
    name = "docker_containers"
    host_path = "/var/lib/docker/containers"
  }
  volume {
    name      = "cgroup"
    host_path = "/sys/fs/cgroup"
  }
  volume {
    name      = "cgroup_host"
    host_path = "/sys/fs/cgroup"
  }
  volume {
    name      = "proc"
    host_path = "/proc"
  }
  volume {
    name      = "docker_root"
    host_path = "/var/lib/docker"
  }
}

resource "aws_ecs_service" "mw_agent_daemon_service" {
  name                   = "mw-agent-daemon-service"
  cluster                = aws_ecs_cluster.nestjs_keval_app_cluster.id
  task_definition        = aws_ecs_task_definition.mw_agent_daemon.arn
  launch_type            = "EC2"
  scheduling_strategy    = "DAEMON"
  enable_execute_command = true
}

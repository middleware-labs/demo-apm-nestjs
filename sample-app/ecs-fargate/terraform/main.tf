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
resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 3000
  protocol = "HTTP"
  target_type = "ip"
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
    target_group_arn = aws_lb_target_group.app_tg.arn
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
  name = "nestECSTaskExecutionRole"
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
  name = "nestECSTaskRole"
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
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name         = "nestjs-app"
      image        = "ghcr.io/middleware-labs/demo-apm-nestjs:local"  # Replace with your actual Docker image
      portMappings = [
        {
          containerPort = 3000,
          hostPort      = 3000,
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      essential = true,
      "logConfiguration": {
          "logDriver": "awsfirelens",
          "options": {
              "Host": "127.0.0.1",
              "Name": "forward",
              "Port": "8006"
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
      "name": "mw-agent",
      "image": "ghcr.io/middleware-labs/mw-host-agent:master",
      "cpu": 256,
      "portMappings": [
          {
              "name": "8006-tcp",
              "containerPort": 8006,
              "hostPort": 8006,
              "protocol": "tcp",
              "appProtocol": "http"
          }
      ],
      "essential": true,
      "environment": [
          {
              "name": "MW_API_KEY",
              "value": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
          },
          {
              "name": "MW_TARGET",
              "value": "https://xxxxx.middleware.io:443"
          }
      ],
      "mountPoints": [],
      "volumesFrom": []
   },
   {
        "name": "log_router",
        "image": "amazon/aws-for-fluent-bit:stable",
        "cpu": 0,
        "portMappings": [],
        "essential": true,
        "environment": [],
        "mountPoints": [],
        "volumesFrom": [],
        "user": "0",
        "firelensConfiguration": {
            "type": "fluentbit",
            "options": {
                "enable-ecs-log-metadata": "true"
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
  launch_type     = "FARGATE"
  platform_version = "LATEST"
  enable_execute_command = true

  network_configuration {
    subnets         = [aws_subnet.public1.id, aws_subnet.public2.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "nestjs-app"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.app_listener
  ]
}

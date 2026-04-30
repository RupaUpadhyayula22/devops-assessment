# Based on the assessment terraform template
# Updated to use current AWS provider syntax (aws_subnets replacing deprecated aws_subnet_ids)

provider "aws" {
  region = var.region
}

# Already provisioned — referenced as data sources
data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default_vpc.id]
  }
}

# Grants ECS permission to pull images from ECR
data "aws_iam_role" "task_ecs" {
  name = "ecsTaskExecutionRole"
}

resource "aws_security_group" "alb_sg" {
  name   = "${var.app_name}-alb-sg"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    description = "Allow HTTP from internet"
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
    Name    = "${var.app_name}-alb-sg"
    Project = var.app_name
  }
}

# Only allows traffic from ALB on port 5000
resource "aws_security_group" "ecs_sg" {
  name   = "${var.app_name}-ecs-sg"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    description     = "Allow traffic from ALB only"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.app_name}-ecs-sg"
    Project = var.app_name
  }
}

resource "aws_lb" "alb" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.subnets.ids

  tags = {
    Name    = "${var.app_name}-alb"
    Project = var.app_name
  }
}

# target_type = "ip" required for Fargate
resource "aws_lb_target_group" "tg" {
  name        = "${var.app_name}-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = {
    Name    = "${var.app_name}-tg"
    Project = var.app_name
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_ecs_cluster" "cluster" {
  name = "${var.app_name}-cluster"

  tags = {
    Name    = "${var.app_name}-cluster"
    Project = var.app_name
  }
}

resource "aws_ecs_task_definition" "task" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.task_ecs.arn

  container_definitions = jsonencode([{
    name      = var.app_name
    image     = var.image_uri
    essential = true
    portMappings = [{
      containerPort = 5000
      hostPort      = 5000
      protocol      = "tcp"
    }]
  }])

  tags = {
    Name    = "${var.app_name}-task"
    Project = var.app_name
  }
}

# desired_count = 2 as per assessment requirements
# assign_public_ip = true allows Fargate to pull from ECR without a NAT gateway
resource "aws_ecs_service" "service" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.subnets.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = var.app_name
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.listener]

  tags = {
    Name    = "${var.app_name}-service"
    Project = var.app_name
  }
}
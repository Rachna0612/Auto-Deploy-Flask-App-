provider "aws" {
  region = "us-east-1" # Change this to your region
}

resource "aws_ecr_repository" "flask_repo" {
  name = "flask-app-repo"
}

resource "aws_ecs_cluster" "flask_cluster" {
  name = "flask-ecs-cluster"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": "ecs-tasks.amazonaws.com"
    }
  }]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "flask_task" {
  family                   = "flask-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "flask-app"
      image     = "${aws_ecr_repository.flask_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "flask_service" {
  name            = "flask-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-0ae8d4963b038a5b0", "subnet-0d120bf95bd227bb0"] # Replace with your subnet IDs
    assign_public_ip = true

    security_groups = ["sg-0b39e7b587a82d53d"] # Replace with security group ID
  }
  
  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_policy]
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.flask_cluster.name
}

output "ecr_repo_url" {
  value = aws_ecr_repository.flask_repo.repository_url
}

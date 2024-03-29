terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            #version = "~> 3.0"
        }
    }
}

// Generic AWS Configs
provider "aws" {
    region = "ap-southeast-2"
    shared_credentials_files = ["C:/Users/Marko/.aws/credentials"]
    profile = "901444280953_CAB432-STUDENT"
}

// Randomly name resources
resource "random_id" "backend-random" {
  keepers = {
    first = "${timestamp()}"
  }

  prefix = "n8039062-backend-"
  byte_length = 6
}

// Randomly name resources
resource "random_id" "worker-random" {
  keepers = {
    first = "${timestamp()}"
  }

  prefix = "n8039062-worker-"
  byte_length = 6
}

// Backend Launch Config
resource "aws_launch_configuration" "n8039062-backend" {
  name                 = random_id.backend-random.hex
  key_name             = "marko-assign1"
  iam_instance_profile = "ec2SSMCab432"
  image_id             = "ami-02eae4391d6cad044"
  instance_type        = "t3.medium"
  security_groups      = ["sg-032bd1ff8cf77dbb9"]
  user_data            = data.template_file.backend.rendered
}

// Worker Launch Config
resource "aws_launch_configuration" "n8039062-worker" {
  name                 = random_id.worker-random.hex
  key_name             = "marko-assign1"
  iam_instance_profile = "ec2SSMCab432"
  image_id             = "ami-02eae4391d6cad044"
  instance_type        = "t3.medium"
  security_groups      = ["sg-032bd1ff8cf77dbb9"]
  user_data            = data.template_file.worker.rendered
}

// Worker Autoscaling Group
resource "aws_autoscaling_group" "n8039062-worker-ASG" {
  name                 = "${aws_launch_configuration.n8039062-worker.name}"
  launch_configuration = aws_launch_configuration.n8039062-worker.name
  min_size             = 1
  max_size             = 5
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity = "1Minute"
  lifecycle {
    create_before_destroy = true
  }
  vpc_zone_identifier = [
    "subnet-05a3b8177138c8b14",
    "subnet-075811427d5564cf9",
    "subnet-04ca053dcbe5f49cc"
  ]
}

// Worker Autoscaling Group Policy
resource "aws_autoscaling_policy" "n8039062-worker-ASG-policy" {
  name                   = "n8039062-worker-ASG-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.n8039062-worker-ASG.name
  policy_type            = "TargetTrackingScaling"
  estimated_instance_warmup = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

// Backend Autoscaling Group
resource "aws_autoscaling_group" "n8039062-backend-ASG" {
  name                 = "${aws_launch_configuration.n8039062-backend.name}"
  launch_configuration = aws_launch_configuration.n8039062-backend.name
  min_size             = 1
  max_size             = 2
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]
  metrics_granularity = "1Minute"

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      load_balancers, target_group_arns
    ]
  }

  vpc_zone_identifier = [
    "subnet-05a3b8177138c8b14",
    "subnet-075811427d5564cf9",
    "subnet-04ca053dcbe5f49cc"
  ]
}

// Backend Autoscaling Group Attachment
resource "aws_autoscaling_attachment" "n8039062-backend-ASG-attachment" {
  autoscaling_group_name  = aws_autoscaling_group.n8039062-backend-ASG.id
  lb_target_group_arn    = aws_lb_target_group.n8039062-backend-target-group.arn
}

// Frontend Autoscaling Group Attachment
resource "aws_autoscaling_attachment" "n8039062-frontend-ASG-attachment" {
  autoscaling_group_name  = aws_autoscaling_group.n8039062-backend-ASG.id
  lb_target_group_arn    = aws_lb_target_group.n8039062-frontend-target-group.arn
}

// Backend Autoscaling Group Policy
resource "aws_autoscaling_policy" "n8039062-backend-ASG-policy" {
  name                   = "n8039062-backend-ASG-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.n8039062-backend-ASG.name
  policy_type            = "TargetTrackingScaling"
  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}

// Backend Target Group
resource "aws_lb_target_group" "n8039062-backend-target-group" {
  name     = "n8039062-backend-target-group"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = "vpc-007bab53289655834"
  tags     = { qut-username = "n8039062"}
  health_check {
    enabled = true
    path = "/health"
    protocol = "HTTP"
    port = 8000
  }
}

// Frontend Target Group
resource "aws_lb_target_group" "n8039062-frontend-target-group" {
  name     = "n8039062-frontend-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-007bab53289655834"
  tags = { qut-username = "n8039062"}
}

// Load Balancer
resource "aws_lb" "n8039062-loadbalancer" {
  name               = "n8039062-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-032bd1ff8cf77dbb9"]
  subnets            =  ["subnet-05a3b8177138c8b14", "subnet-075811427d5564cf9", "subnet-04ca053dcbe5f49cc"
  ]
  enable_deletion_protection = true
  tags = { qut-username = "n8039062"}
}

// Backend Listener
resource "aws_lb_listener" "n8039062-8000-listener" {
  load_balancer_arn = aws_lb.n8039062-loadbalancer.arn
  port              = "8000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.n8039062-backend-target-group.arn
  }
  tags = { qut-username = "n8039062"}
}

// Frontend Listener
resource "aws_lb_listener" "n8039062-80-listener" {
  load_balancer_arn = aws_lb.n8039062-loadbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.n8039062-frontend-target-group.arn
  }
  tags = { qut-username = "n8039062"}
}

// SQS Queue
resource "aws_sqs_queue" "n8039062-Assign2-SQS" {
  name = "n8039062-Assign2-SQS"
  tags = { qut-username = "n8039062"}
}

// SQS Policy
resource "aws_sqs_queue_policy" "SQS_policy" {
  queue_url = aws_sqs_queue.n8039062-Assign2-SQS.id
  policy = data.aws_iam_policy_document.SQS_policy_doc.json
}

// SQS Access Policy
data "aws_iam_policy_document" "SQS_policy_doc" {
  statement {
    sid = "_AllActions"
    effect = "Allow"
    actions   = ["sqs:*"]
    resources = ["arn:aws:sqs:ap-southeast-2:901444280953:n8039062-Assign2-SQS"]
    principals {
      type = "AWS"
      identifiers = ["arn:aws:iam::901444280953:role/ec2SSMCab432",
                     "arn:aws:iam::901444280953:root"]
    }
  }
}

// Backend Templete File
data "template_file" "backend" {
  template = "${file("./template_file.tpl")}"

  vars = {
    GITHUB_TOKEN = var.GITHUB_TOKEN
    DB_CONNECTION = var.DB_CONNECTION
    DB_HOST = var.MYSQL_ENDPOINT
    DB_PORT = var.DB_PORT
    DB_DATABASE = var.DB_DATABASE
    DB_USERNAME = var.DB_USERNAME
    DB_PASSWORD = var.DB_PASSWORD
    REDIS_HOST = var.REDIS_ENDPOINT
    CONTAINER_1 = "ghcr.io/markopteryx/cab432-n8039062-backend:main"
    CONTAINER_2 = "ghcr.io/markopteryx/cab432-n8039062-frontend:main"
    API_URL = aws_lb.n8039062-loadbalancer.dns_name
    COMPOSE = file("${path.module}/ami/docker-compose-backend.yml")
  }
}

// Worker Templete File
data "template_file" "worker" {
  template = "${file("./template_file.tpl")}"

  vars = {
    GITHUB_TOKEN = var.GITHUB_TOKEN
    DB_CONNECTION = var.DB_CONNECTION
    DB_HOST = var.MYSQL_ENDPOINT
    DB_PORT = var.DB_PORT
    DB_DATABASE = var.DB_DATABASE
    DB_USERNAME = var.DB_USERNAME
    DB_PASSWORD = var.DB_PASSWORD
    REDIS_HOST = var.REDIS_ENDPOINT
    CONTAINER_1 = "ghcr.io/markopteryx/cab432-n8039062-worker:main"
    CONTAINER_2 = "ghcr.io/markopteryx/cab432-n8039062-worker:main"
    API_URL = aws_lb.n8039062-loadbalancer.dns_name
    COMPOSE = file("${path.module}/ami/docker-compose-worker.yml")
  }
}

// Variables
variable "GITHUB_TOKEN" {
    description = "A personal access token with read:packages permissions"
    type = string
}

variable "DB_CONNECTION" {
    description = "The type of RDS used"
    default = "mysql"
    type = string
}

variable "DB_PORT" {
    description = "The port of the RDS"
    default = "3306"
    type = string
}

variable "DB_DATABASE" {
    description = "The name of the RDS"
    default = "renders"
    type = string
}

variable "DB_USERNAME" {
    description = "The username of the RDS"
    default = "admin"
    type = string
}

variable "DB_PASSWORD" {
    description = "The address of the RDS"
    type = string
}

variable "REDIS_ENDPOINT" {
    default = "n8039062-redis.km2jzi.ng.0001.apse2.cache.amazonaws.com"
    description = "AWS Redis Primary Endpoint"
    type = string
}

variable "MYSQL_ENDPOINT" {
    default = "n8039062-assign2.ce2haupt2cta.ap-southeast-2.rds.amazonaws.com"
    description = "AWS MySQL Primary Endpoint"
    type = string
}

output "URL" {
  value = aws_lb.n8039062-loadbalancer.dns_name
}

resource "local_file" "url" {
  content = format("http://%s", aws_lb.n8039062-loadbalancer.dns_name)
  filename = "./api.txt"
}
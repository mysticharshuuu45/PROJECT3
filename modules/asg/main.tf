
# Standalone EC2 Instance (Optional)
resource "aws_instance" "harshres" {
  ami           = "ami-09b0a86a2c84101e1" # Replace with correct AMI
  instance_type = "t2.micro"
  key_name      = "key_name"              # Ensure this key exists in AWS
  tags = {
    Name = "myterraforminst"
  }
}

# Launch Template
resource "aws_launch_template" "vpc_launch_template" {
  name          = "${var.project_name}-tpl"
  image_id      = var.ami
  instance_type = var.cpu
  key_name      = var.key_name
  user_data     = filebase64("../modules/asg/config.sh")

  vpc_security_group_ids = [var.client_sg_id]
  tags = {
    Name = "${var.project_name}-tpl"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "asg_name" {
  name                      = "${var.project_name}-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_cap
  health_check_grace_period = 300
  health_check_type         = var.asg_health_check_type
  vpc_zone_identifier       = [var.pri_sub_3a_id, var.pri_sub_4b_id]
  target_group_arns         = [var.tg_arn]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  launch_template {
    id      = aws_launch_template.vpc_launch_template.id
    version = aws_launch_template.vpc_launch_template.latest_version
  }

  # Corrected tagging format for AWS provider >= 4.0.0
  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = true
  }
}

# Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-asg-scale-up"
  autoscaling_group_name = aws_autoscaling_group.asg_name.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-asg-scale-down"
  autoscaling_group_name = aws_autoscaling_group.asg_name.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
  policy_type            = "SimpleScaling"
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "${var.project_name}-asg-scale-up-alarm"
  alarm_description   = "Triggers scale-up when CPU usage exceeds 70%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg_name.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "${var.project_name}-asg-scale-down-alarm"
  alarm_description   = "Triggers scale-down when CPU usage drops below 5%"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 5
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg_name.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_down.arn]
}

# Outputs (Optional for Debugging)
output "asg_id" {
  value = aws_autoscaling_group.asg_name.id
}

output "launch_template_id" {
  value = aws_launch_template.vpc_launch_template.id
}

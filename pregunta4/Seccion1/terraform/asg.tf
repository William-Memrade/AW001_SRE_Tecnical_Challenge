data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "web-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  network_interfaces {
    security_groups             = [aws_security_group.web_sg.id]
    associate_public_ip_address = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }

  user_data = filebase64("${path.module}/scripts/user_data.sh")

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "web-launch-template"
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name                = "web-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.web_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-server-asg"
    propagate_at_launch = true
  }
}

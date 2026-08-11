resource "aws_lb" "internal" {
  name_prefix        = substr(var.name_prefix, 0, 6)
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.private_subnet_ids

  drop_invalid_header_fields = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-internal-alb" })
}

resource "aws_lb_target_group" "dashboard" {
  name_prefix = "wzd-"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/app/login"
    protocol            = "HTTPS"
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-dashboard-tg" })

  lifecycle { create_before_destroy = true }
}

resource "aws_lb_target_group_attachment" "dashboard" {
  count            = length(var.target_instance_ids)
  target_group_arn = aws_lb_target_group.dashboard.arn
  target_id        = var.target_instance_ids[count.index]
  port             = 443
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
  }
}

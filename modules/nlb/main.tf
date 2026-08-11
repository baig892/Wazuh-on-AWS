# Internal NLB for Wazuh agent traffic.
# TCP is used because Wazuh agents connect directly to manager ports.

resource "aws_lb" "agents" {
  name_prefix        = substr(var.name_prefix, 0, 6)
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  tags = merge(var.tags, { Name = "${var.name_prefix}-agent-nlb" })
}

resource "aws_lb_target_group" "agent_events" {
  name_prefix = "wzev-"
  port        = 1514
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = "1514"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-agent-events-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "agent_enrollment" {
  name_prefix = "wzen-"
  port        = 1515
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = "1515"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-agent-enrollment-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group_attachment" "agent_events" {
  count            = length(var.manager_instance_ids)
  target_group_arn = aws_lb_target_group.agent_events.arn
  target_id        = var.manager_instance_ids[count.index]
  port             = 1514
}

resource "aws_lb_target_group_attachment" "agent_enrollment" {
  count            = length(var.manager_instance_ids)
  target_group_arn = aws_lb_target_group.agent_enrollment.arn
  target_id        = var.manager_instance_ids[count.index]
  port             = 1515
}

resource "aws_lb_listener" "agent_events" {
  load_balancer_arn = aws_lb.agents.arn
  port              = 1514
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent_events.arn
  }
}

resource "aws_lb_listener" "agent_enrollment" {
  load_balancer_arn = aws_lb.agents.arn
  port              = 1515
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agent_enrollment.arn
  }
}

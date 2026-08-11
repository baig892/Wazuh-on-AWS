output "cloudtrail_bucket" {
  value = aws_s3_bucket.cloudtrail.id
}

output "config_bucket" {
  value = aws_s3_bucket.config.id
}

output "vpn_log_group" {
  value = aws_cloudwatch_log_group.vpn.name
}

output "alarms_topic_arn" {
  value = aws_sns_topic.alarms.arn
}

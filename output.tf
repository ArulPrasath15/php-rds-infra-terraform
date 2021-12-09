output "mysql_endpoint_dns" {
  value = aws_db_instance.mysql.address
}

output "alb_endpoint" {
  value = aws_lb.alb.dns_name
}
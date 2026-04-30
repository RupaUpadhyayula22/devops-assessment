output "alb_dns" {
  value       = aws_lb.alb.dns_name
  description = "Public DNS of the Application Load Balancer hit this on port 80 to reach the app"
}
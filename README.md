# Platform Assessment

A Flask "Hello, World" application deployed on AWS Fargate using Terraform and GitHub Actions CI/CD.

## Architecture

- **Application**: Python Flask app containerized with Docker
- **Container Registry**: AWS ECR (ap-northeast-2)
- **Orchestration**: AWS ECS Fargate with 2 replicas
- **Load Balancing**: AWS Application Load Balancer on port 80
- **Infrastructure as Code**: Terraform
- **CI/CD**: GitHub Actions

## Live URL
http://platform-assessment-alb-2106609989.ap-northeast-2.elb.amazonaws.com

## CI/CD Pipeline

**On Pull Request:**
- Runs pytest test suite
- Runs flake8 linting (bonus)
- Blocks merge if any check fails

**On Merge to main:**
- Builds Docker image for linux/amd64
- Pushes to ECR (creates repo if not exists)
- Forces new ECS deployment with zero downtime

## Infrastructure

Terraform manages all AWS resources:
- ECS Cluster, Task Definition, Service (2 replicas)
- Application Load Balancer + Target Group + Listener
- Security Groups (ALB and ECS scoped separately)
- References pre-existing VPC, Subnets and ecsTaskExecutionRole

## Local Development

```bash
# Run locally
python -m venv venv
source venv/bin/activate
pip install flask pytest
python setup.py install
FLASK_APP=hello flask run

# Run tests
pytest tests/ -v

# Run with Docker
docker build -t platform-assessment .
docker run -p 8000:5000 platform-assessment
```

## Infrastructure Deployment

```bash
cd terraform
terraform init
terraform apply -var="image_uri=<ECR_URI>:latest"
```

## Design Decisions

- **linux/amd64 platform**: Explicitly set in Dockerfile for AWS Fargate compatibility (Mac M-series builds ARM64 by default)
- **assign_public_ip = true**: Allows Fargate tasks to pull images from ECR without a NAT gateway
- **Local Terraform state**: No S3 access in the assessment account
- **aws_subnets over aws_subnet_ids**: Updated from deprecated data source in the provided template

## Next Steps

- Add HTTPS with ACM certificate on the ALB
- Add CloudWatch log groups for container logging
- Add Terraform remote state using an alternative backend
- Add container health checks in task definition
- Add auto-scaling policy based on CPU/memory metrics

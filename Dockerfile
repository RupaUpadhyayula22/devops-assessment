# linux/amd64 platform required for AWS Fargate compatibility
FROM --platform=linux/amd64 python:3.9-slim

WORKDIR /app

COPY . .

RUN pip install setuptools flask
RUN python setup.py install

ENV FLASK_APP=hello

EXPOSE 5000

# Bind to 0.0.0.0 to allow traffic from outside the container
CMD ["flask", "run", "--host=0.0.0.0"]
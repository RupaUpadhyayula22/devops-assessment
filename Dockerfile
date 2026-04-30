FROM python:3.9-slim

WORKDIR /app

COPY . .

RUN pip install setuptools flask
RUN python setup.py install

ENV FLASK_APP=hello

EXPOSE 5000

CMD ["flask", "run", "--host=0.0.0.0"]
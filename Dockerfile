
FROM python:3.9-slim

WORKDIR /app

COPY app.py .

RUN pip install flask


ENV APP_MESSAGE="Welcome from inside Docker!"

EXPOSE 5000


CMD ["python", "app.py"]


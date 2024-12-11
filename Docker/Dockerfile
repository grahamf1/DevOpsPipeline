FROM python:3.12.3-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir wheel setuptools

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV FLASK_APP=cv
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_ENV=production
ENV AZURE_COSMOS_CONNECTION_STRING="ConnectionString"

EXPOSE 5000

CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "cv:app"]
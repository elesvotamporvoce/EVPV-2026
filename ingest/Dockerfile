FROM python:3.12-slim

WORKDIR /app

# Dependências primeiro (cache de camada)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ingest_camara.py ingest_senado.py ./

# Default: Câmara. O serviço 'ingest-senado' no compose sobrescreve o entrypoint.
ENTRYPOINT ["python", "ingest_camara.py"]

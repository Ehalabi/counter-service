# Stage 1
FROM python:3.12-slim AS build

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

RUN pip install --no-cache-dir pytest
RUN pytest -sv

# Stage 2
FROM python:3.12-slim

WORKDIR /app

COPY --from=build /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=build /app/counter_service.py /app

RUN useradd -ms /bin/bash nonroot 

USER nonroot

EXPOSE 8000

CMD ["gunicorn", "-b", "0.0.0.0:8000", "-w", "2" ,"counter_service:app"]

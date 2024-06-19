FROM ubuntu:24.04

RUN apt update && apt install curl python3 -y

ENTRYPOINT ["python3", "-m", "http.server", "9000"]
FROM mdillon/postgis:9.6

# For building and running the image, let dpkg/apt know that we install and
# configure non-interactively.
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y \
    && apt-get install -y netcat

COPY ./pg_tune.py /
COPY custom-docker-entrypoint.sh /
RUN chmod +x /custom-docker-entrypoint.sh

ENTRYPOINT /custom-docker-entrypoint.sh

FROM mdillon/postgis:10

# For building and running the image, let dpkg/apt know that we install and
# configure non-interactively.
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt-get update -y \
    && apt-get install -y apt-utils tzdata python \
		&& rm -rf /var/lib/apt/lists/*

COPY ./pg_tune.py /
COPY custom-docker-entrypoint.sh /
RUN chmod +x /custom-docker-entrypoint.sh

ENTRYPOINT /custom-docker-entrypoint.sh

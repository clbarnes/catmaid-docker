FROM nginx:mainline

# For building and running the image, let dpkg/apt know that we install and
# configure non-interactively.
ENV DEBIAN_FRONTEND=noninteractive

# Install basic HTTP authentication tools (htpasswd)
RUN apt-get update -y \
    && apt-get install -y apache2-utils \
    && rm -rf /var/lib/apt/lists/*

RUN rm /etc/nginx/conf.d/default.conf
COPY ./catmaid /etc/nginx/sites-available/
#COPY ./catmaid-ssl /etc/nginx/sites-available/

COPY docker-entry.sh /
RUN chmod +x /docker-entry.sh
ENTRYPOINT /docker-entry.sh

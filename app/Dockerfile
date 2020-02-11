# adapted from catmaid dockerfile
FROM ubuntu:16.04
LABEL maintainer="Chris Barnes <chrislloydbarnes@gmail.com>"

# For building the image, let dpkg/apt know that we install and configure
# non-interactively.
ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies. Even though this image doesn't run its own Postgres
# instance, make sure we install the upstream version to match the manual (and
# make building images on top of this one easier).
RUN apt-get update -y \
    && apt-get install -y apt-utils gawk \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    # && add-apt-repository -y ppa:nginx/stable \
    # && add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" \
    # && apt-get install -y wget ca-certificates \
    # && wget --quiet -O - https://postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update -y \
    && apt-get install -y python3.6 python3.6-dev git python-pip \
    # && apt-get install -y nginx supervisor \
    && apt-get install -y supervisor

# Set up SSH so that we can access the environment easily
# https://stackoverflow.com/a/37246331
RUN apt-get install -y openssh-server \
    && mkdir /var/run/sshd \
    && chmod 0755 /var/run/sshd \
    && /usr/sbin/sshd \
    && useradd -m -s /bin/bash --groups sudo catmaid_user \
    && usermod -G sudo catmaid_user \
    && passwd catmaid_user catmaid_password \
    && ifconfig | awk '/inet addr/{print substr($2,6)}'

RUN apt-get update -y  \
    && xargs apt-get install -y < /home/CATMAID/packagelist-ubuntu-16.04-apt.txt

ENV WORKON_HOME /opt/virtualenvs
RUN mkdir -p /opt/virtualenvs \
    && /bin/bash -c "source /usr/share/virtualenvwrapper/virtualenvwrapper.sh \
    && mkvirtualenv catmaid -p /usr/bin/python3.6 \
    && workon catmaid \
    && pip install -U pip setuptools \
    && pip install \
        -r /home/CATMAID/django/requirements-dev.txt \
        -r /home/CATMAID/django/requirements-optional.txt \
    " \
    && echo "source /usr/share/virtualenvwrapper/virtualenvwrapper.sh" >> ~/.bashrc

# todo: probably not necessary
RUN cd /home/ && git describe > /home/git-version

# # uWSGI setup
# RUN /bin/bash -c "workon catmaid && pip install uwsgi" \
#     && ln -s /home/CATMAID/scripts/docker/supervisor-catmaid.conf /etc/supervisor/conf.d/ \
#     && chmod +x /home/CATMAID/scripts/docker/start-catmaid.sh \
#     && chmod +x /home/CATMAID/scripts/docker/catmaid-entry.sh

# Fix AUFS bug that breaks PostgreSQL
# See: https://github.com/docker/docker/issues/783
RUN mkdir /etc/ssl/private-copy; \
    mv /etc/ssl/private/* /etc/ssl/private-copy/; \
    rm -r /etc/ssl/private; \
    mv /etc/ssl/private-copy /etc/ssl/private; \
    chmod -R 0700 /etc/ssl/private; \
    chown -R postgres /etc/ssl/private

EXPOSE 22
EXPOSE 8000
WORKDIR /home/CATMAID
ENTRYPOINT ["/bin/bash"]

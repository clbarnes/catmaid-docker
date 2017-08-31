# catmaid-docker

Docker compose application for CATMAID

A more detailed explanation can be found in the [CATMAID
documentation](http://catmaid.readthedocs.io/en/stable/docker.html). To
run this docker-compose setup, you first have to install Docker-compose:

```
sudo sh -c "curl -L https://github.com/docker/compose/releases/download/1.15.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
sudo chmod +x /usr/local/bin/docker-compose
sudo sh -c "curl -L https://raw.githubusercontent.com/docker/compose/1.8.0/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose"
```

Next clone the ``catmaid-compose`` repo to a convenient location. Note that by
default the database will be stored in this location, too:

```
git clone https://github.com/catmaid/catmaid-docker.git
cd catmaid-docker
```

The database (and static files) will be saved outside of the containers in the
folder ``volumes``. This allows to optionally create a symlink with this name to
a different location for the database.

Run containers:

```
docker-compose up
```

Navigate your browser to [http://localhost:8000](http://localhost:8000)
and you should see the CATMAID front page. You can log in as a superuser
with username "admin" and password "admin". The Docker image contains a few
example projects, which are added by default. To disable these, set
``CM_EXAMPLE_PROJECTS=false`` in the ``environment`` section of the ``app``
service in ``docker-compose.yaml`` before starting the containers for the
first time. This is also the place where database details can be configured.

*Warning:* Make sure you change the default password of the admin user.

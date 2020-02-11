# catmaid-dev-docker

WIP docker-compose application for CATMAID development.

## TODO

- [ ] user needs password for SSH
- [ ] everything else

## Concept

A whole development environment in a can.
The OS, and all of the OS-level dependencies are handled,
and there's a complete python environment, including all the required linters etc..

Good IDEs connect to the container over SSH ([VSCode](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh), [PyCharm](https://www.jetbrains.com/help/pycharm/configuring-remote-interpreters-via-ssh.html)),
allowing your local instance of the IDE to use the internal python environment.
The live code is a volume: changes made inside the container are persisted on the outside,
and changes made on the outside affect the live environment.
So there's no need to rebuild (unless you change the dependencies).

The database lives in its own container, also with a volume so that changes are persisted.

## Limitations

- This is not for use in production.
- This is only intended to handle CATMAID's dependencies - you still need to configure and run CATMAID inside the container.

## Usage

- Clone this repo
- Clone the CATMAID repository into ./app/CATMAID
- Run the containers with `docker-compose up`

### Accessing the containers

The IP addresses of the CATMAID (`app`) and database (`db`) containers can be found with

```sh
CATMAID_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' app)
DB_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' db)
```

- CATMAID container accessible over SSH at port 22
- CATMAID dev server, when started, accessible at port 80
- Database accessible on port 5432

Original README below:

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

## Run containers:

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

## Updating:

Before updating the docker images, the database should be backed up. The easiest
way to do this and also be able to quickly restore in case something goes wrong,
is to perform a file based copy of the `volumes` folder after stopping the
database. To stop the database, call the following three commands from the
`catmaid-docker` directory (containing the `docker-compose.yml` file):

```
PG_STOP_CMD='export PGCTL=$(which pg_ctl); su postgres -c "${PGCTL} stop"'
docker exec -i -t catmaid-docker_db_1 /bin/bash -c "${PG_STOP_CMD}"
docker-compose stop
```

And then copy the complete `volumes` folder:

```
sudo cp -r volumes volumes.backup
```

Next update your local copy of the `docker-compose` repository:

```
git pull origin master
```

Then update your docker images:

```
docker-compose pull
```

Finally the docker containers have to be built and started again:

```
docker-compose up --build
```

In case a newly pulled docker image introduces a new Postgres version, CATMAID’s
docker-compose start-up script will detect this and abort the container
execution with a warning. This warning says that an automatic update of the data
files can be performed, but this will only be done if `DB_UPDATE=true` is set in
the `docker-compose.yml` file. If you don’t see such a warning, the update should
be successful. If you see this warning, a few additional steps are required.
First `DB_UPDATE=true` has to be added as environment variable of the `db` app in
the `docker-compose.yml` file. The docker-compose setup needs then to be rebuilt
and run:

```
docker-compose up --build
```

After a successful upgrade, the `DB_UPDATE` variable should be set to `false`
again, to not accidentally upgrade the data files without ensuring a back-up has
been made.

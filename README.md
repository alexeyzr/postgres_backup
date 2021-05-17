
This is a simple backup procedure for simple cases and educational purposes.

It will save PostgreSQL DB backups to a local directory if you set environment variable `SAVE_TO_DISK=true` or to AWS S3 if `SAVE_TO_DISK=false`.

__1. Setup postgres db__

The docker image from there will be used 

 https://hub.docker.com/_/postgres

* Create `docker-compose.yml` file

```
version: "3.3"
services:
  postgres:
    build:
      context: ./Postgres
      dockerfile: postgres.Dockerfile
    env_file:
      - postgres.env
    restart: always
   #volumes:
   #  - ./var/pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
```

* Sample DB initialization in `./Postgres/init.sql` file

```
CREATE USER myUser;

CREATE DATABASE myApp_dev;
GRANT ALL PRIVILEGES ON DATABASE myApp_dev TO myUser;
```

* Add it into your `postgres.Dockerfile`

```
FROM postgres:latest
COPY init.sql /docker-entrypoint-initdb.d/
```

* Postgres environment variables

Create `postgres.env` file
```
POSTGRES_USER=myUser
POSTGRES_PASSWORD=myPassword
POSTGRES_DB=myApp_dev
```

__2. Setup backup procedure__

Backup PostgresSQL to the local filesystem or AWS S3


* Lets add this part to our `docker-compose.yml` file

```
  pgbackups:
    build:
      context: ./PostgresBackup
      dockerfile: alpine.Dockerfile
    restart: always
    user: postgres:postgres
    volumes:
        - /var/opt/pgbackups:/backups
    links:
        - postgres
    depends_on:
        - postgres
    env_file:
      - postgres.env
      - aws.env
      - rclone.env
    environment:
            - SAVE_TO_DISK=true
            - POSTGRES_HOST=postgres
            - POSTGRES_EXTRA_OPTS=-Z6 --schema=public --blobs
            - SCHEDULE=@daily
            - HEALTHCHECK_PORT=8080

```

* Add AWS credential to `aws.env` file

```
AWS_DEFAULT_REGION=
AWS_SECRET_ACCESS_KEY=
AWS_ACCESS_KEY_ID=
```

* Add rclone configguration file `PostgresBackup/rclone.conf`

Here is a sample config file. 
```
[backup]
type = s3
provider = AWS
env_auth = true
region = us-east-2
location_constraint = us-east-2
acl = private
storage_class = STANDARD
```

You can create your own by the `rclone config` command.


* Add `rclone.env` file

Set `RCLONE_CONFIG_NAME` as your desire name configuration in `rclone.conf` and set `AWS_S3_BUCKET` to S3 bucket where backup will be saved.

```
RCLONE_CONFIG_NAME=
AWS_S3_BUCKET=
```

__3. Composing and starting services__
```
docker-compose -f docker-compose.yml up --no-start
docker-compose -f docker-compose.yml start
```

__4. Some tests__

Connect from host where postgres docker container is running
```
$ psql -U myUser -d myApp_dev -hlocalhost
```
Let's add some data
```
myApp_dev=# \d
Did not find any relations.

myApp_dev=# CREATE TABLE test_table(name TEXT);
CREATE TABLE
myApp_dev=# \d
          List of relations
 Schema |    Name    | Type  | Owner
--------+------------+-------+--------
 public | test_table | table | myUser
(1 row)

myApp_dev=# SELECT * FROM test_table;
 name
------
(0 rows)

myApp_dev=# INSERT INTO test_table VALUES ('mydata');
INSERT 0 1
myApp_dev=# SELECT * FROM test_table;
  name
--------
 mydata
(1 row)
```

__5. Manual Backup__

Our backup procedure will make backups on regular basis but you can do it in manuall too.

Create the local backup directory and grant permission to the `postgre` user (id 70 for `postgres:alpine` docker image).

```
sudo mkdir -p /var/opt/pgbackups && sudo chown -R 70:70 /var/opt/pgbackup
```
```
$ docker exec -it $BACKUP_CONTAINER_ID /bin/bash
```
You could check `SAVE_TO_DISK` environment variable and set it to `true` value to save the backup 
on local directory.

```
bash-5.1$ ./backup.sh
Creating dump of myApp_dev database from postgres...
Done!
```
Or set `SAVE_TO_DISK=false` to save the backup on AWS S3 bucket 
```
bash-5.1$ export SAVE_TO_DISK=false
bash-5.1$ ./backup.sh
Creating dump of myApp_dev database from postgres...
Done!
```
Check the S3 bucket by the command 
```
rclone ls $RCLONE_CONFIG_NAME:$AWS_S3_BUCKET
```

__6. Restore from backup__

```
$ cd cd /var/opt/pgbackups/
$ zcat backupfile.sql.gz | docker exec -i $DB_CONTAINER_ID psql --username=myUser --dbname=myApp_dev
```


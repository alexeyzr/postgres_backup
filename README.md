
This is a simple backup procedure for simple cases and educational purposes.

__1. Setup postgres db__

The docker image from there will be used 

 https://hub.docker.com/_/postgres

* Create `docker-compose.yml` file

```
version: "3.3"
services:
  postgres:
    build:
      context: ./Docker
      dockerfile: postgres.Dockerfile
    env_file:
      - postgres.env
    restart: always
   #volumes:
   #  - ./var/pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
```

* Sample DB initialization in `./Docker/init.sql` file

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

Backup PostgresSQL to the local filesystem with periodic rotating backups

 https://hub.docker.com/r/prodrigestivill/postgres-backup-local

* Lets add this part to our `docker-compose.yml` file

```
  pgbackups:
    image: prodrigestivill/postgres-backup-local
    restart: always
    user: postgres:postgres
    volumes:
        - /var/opt/pgbackups:/backups
    links:
        - postgres
    depends_on:
        - postgres
    env_file:
      - database.env
    environment:
            - POSTGRES_HOST=postgres
        #   - POSTGRES_DB=database
        #   - POSTGRES_USER=username
        #   - POSTGRES_PASSWORD=password
        #   - POSTGRES_PASSWORD_FILE=/run/secrets/db_password <-- alternative for POSTGRES_PASSWORD (to use with docker secrets)
            - POSTGRES_EXTRA_OPTS=-Z6 --schema=public --blobs
            - SCHEDULE=@daily
            - BACKUP_KEEP_DAYS=7
            - BACKUP_KEEP_WEEKS=4
            - BACKUP_KEEP_MONTHS=6
	    - HEALTHCHECK_PORT=8080
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
```
docker pull prodrigestivill/postgres-backup-local
```
```
sudo mkdir -p /var/opt/pgbackups && sudo chown -R 999:999 /var/opt/pgbackup
```
```
$ docker exec -it $BACKUP_CONTAINER /bin/bash
```
```
postgres@84bb2eb6cce5:/$ ./backup.sh
Creating dump of myApp_dev database from db...
'/backups/weekly/myApp_dev-202119.sql.gz' => '/backups/daily/myApp_dev-20210513-170339.sql.gz'
'/backups/monthly/myApp_dev-202105.sql.gz' => '/backups/daily/myApp_dev-20210513-170339.sql.gz'
Cleaning older than 7 days for myApp_dev database from db...
SQL backup created successfully
postgres@84bb2eb6cce5:/$ exit
exit
```

__6. Restore from backup__

```
$ cd cd /var/opt/pgbackups/{daily,monthly,weekly}
$ zcat backupfile.sql.gz | docker exec -i $CONTAINER psql --username=myUser --dbname=myApp_dev
```


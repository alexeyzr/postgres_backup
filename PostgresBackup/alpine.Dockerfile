ARG BASETAG=alpine
FROM postgres:$BASETAG

ARG GOCRONVER=v0.0.10
ARG TARGETOS=linux
ARG TARGETARCH=amd64

RUN set -x \
	&& apk update && apk add ca-certificates curl


RUN set -x \
        && cd tmp \
	&& curl -O https://downloads.rclone.org/rclone-current-$TARGETOS-$TARGETARCH.zip \
        && unzip rclone-current-$TARGETOS-$TARGETARCH.zip \
        && cp ./rclone-*-$TARGETOS-$TARGETARCH/rclone /usr/bin \
        && chown root:root /usr/bin/rclone \
        && chmod 755 /usr/bin/rclone \
        && rm -rf rclone-* \
        && cd /
   
COPY rclone.conf /var/lib/postgresql/.config/rclone/

RUN set -x \
        && chown -R 70:70 /var/lib/postgresql/.config/rclone/

RUN set -x \ 
        && curl -L https://github.com/prodrigestivill/go-cron/releases/download/$GOCRONVER/go-cron-$TARGETOS-$TARGETARCH-static.gz | zcat > /usr/local/bin/go-cron \
	&& chmod a+x /usr/local/bin/go-cron

USER postgres

ENV POSTGRES_PORT=5432 \
    POSTGRES_EXTRA_OPTS="-Z6" \
    SCHEDULE="@daily" \
    BACKUP_DIR="/backups" \
    BACKUP_SUFFIX=".sql.gz" \
    BACKUP_KEEP_DAYS=7 \
    BACKUP_KEEP_WEEKS=4 \
    BACKUP_KEEP_MONTHS=6 \
    HEALTHCHECK_PORT=8080

COPY backup.sh /backup.sh

VOLUME /backups

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["exec /usr/local/bin/go-cron -s \"$SCHEDULE\" -p \"$HEALTHCHECK_PORT\" -- /backup.sh"]

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f "http://localhost:$HEALTHCHECK_PORT/" || exit 1

#!/usr/bin/env bash

set -e

for ENV_VAR in POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD POSTGRES_HOST POSTGRES_PORT BACKUP_DIR; do 
   if [[ -z ${!ENV_VAR} ]]; then
	  echo "You need to set the ${ENV_VAR} environment variable."
	  exit 1
   fi
done

export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"

[[ ! -d "${BACKUP_DIR}" ]] && mkdir -p "${BACKUP_DIR}"

#Backup all databases
POSTGRES_DBS=$(echo "${POSTGRES_DB}" | tr , " ")
for DB in ${POSTGRES_DBS}; do
    BAK_DB_FILE="${BACKUP_DIR}/${DB}-`date +%Y%m%d-%H%M%S`${BACKUP_SUFFIX}"
    echo "Creating dump of ${DB} database from ${POSTGRES_HOST}..."
    pg_dump -d "${DB}" -f "${BAK_DB_FILE}" ${POSTGRES_EXTRA_OPTS}
    if [ "${SAVE_TO_DISK}" = "true" -o ! "${SAVE_TO_DISK}" ]; then
         # Save to disk only
         # Extra command may be here
         :
    else
         # Save to AWS S3
	 rclone copy "${BAK_DB_FILE}" "${RCLONE_CONFIG_NAME}:${AWS_S3_BUCKET}"
	 rm "${BAK_DB_FILE}"
    fi
done


echo "Done!"

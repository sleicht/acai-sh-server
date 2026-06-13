FROM restic/restic:0.18.1

# Install PostgreSQL 17 client tools to match the postgres:17.9 server
RUN apk add --no-cache postgresql17-client curl

# Verify pg_dump is available
RUN pg_dump --version

# Bake the backup scripts into the image so no host bind mount is required.
# Relative bind mounts (./backup) don't resolve on the Docker daemon host under
# Portainer, so the scripts must live in the image instead.
COPY entrypoint.sh run-backup.sh /opt/backup/
RUN chmod +x /opt/backup/entrypoint.sh /opt/backup/run-backup.sh

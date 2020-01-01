#!/usr/bin/env bash

CONFIG_FILE="/etc/backups.conf"

# A simple wrapper for a Gentoo ebuild-like `die`.
die() {
    echo "$*" 1>&2
    exit 1
}

# Source the configuration file.
[[ -f ${CONFIG_FILE} ]] || die "Cannot find ${CONFIG_FILE}. Exiting."
source ${CONFIG_FILE}
# Check the required / optional variables.
[[ -z ${BACKUP_DIR} ]] && die "BACKUP_DIR is not set."
[[ -z ${BACKUP_EXT} ]] && BACKUP_EXT=".tar.gz" # default compression format
[[ -z ${BACKUP_AGE} ]] && BACKUP_AGE=2 # 2 day-old backups stored by default
# Set the date to be inserted to tarball names.
BACKUP_DATE="$(date +%Y-%m-%d-%H-%M)"

# Wrapper around `mkdir -p`.
mkdir_p() {
    [[ ! -d "${1}" ]] && mkdir -p "${1}" && \
        echo "Created ${1} for you."
}

# Create the backup directory if it does not exist yet.
mkdir_p ${BACKUP_DIR}

# Creates an empty tar archive. Accepts a single parameter, the filename.
empty_archive() {
    /usr/bin/env tar -cf "${1}" -T /dev/null --xattrs || \
        die "Creating ${1} failed!"
    # This works on BSD and Linux. Not tested with others.
}
# Accepts two parameters, the archive filename and the file to be added.
add_to_archive() {
    /usr/bin/env tar --xattrs --append -pf 2>/dev/null "${1}" "${2}" || \
        die "Adding ${2} to ${1} failed!"
}

clean_up() {
    /usr/bin/env find "${1}" -ctime +${BACKUP_AGE} -delete || \
        die "Cleanup failed!"
}

backup_docker() {
    echo "Running a Docker volumes backup..."
    if [[ -z ${BACKUP_DIR_DOCKER} ]]; then
        BACKUP_DIR_DOCKER=${BACKUP_DIR}
    fi
    mkdir_p ${BACKUP_DIR_DOCKER}
    filename="${BACKUP_DIR_DOCKER}/${BACKUP_DATE}-docker${BACKUP_EXT}"
    # Check the presence of the Docker directory.
    [[ -d /var/lib/docker ]] || die "Docker is likely to not be installed."
    empty_archive ${filename}
    add_to_archive ${filename} /var/lib/docker/volumes
}

backup_postgres() {
    echo "Running a PostgreSQL databases backup..."
    if [[ -z ${BACKUP_DIR_POSTGRES} ]]; then
        BACKUP_DIR_POSTGRES=${BACKUP_DIR}
    fi
    mkdir_p ${BACKUP_DIR_POSTGRES}
    filename="${BACKUP_DIR_POSTGRES}/${BACKUP_DATE}-postgres${BACKUP_EXT}"
    # The databases need to be listed in a special variable.
    [[ -z ${BACKUP_DATABASES} ]] && die "The databases list is not specified."
    for database in "${BACKUP_DATABASES[@]}"; do
        dump_name="${filename}-${database}"
        pg_dump -Fc $database > ${dump_name} || \
            die "Failed backing up database $database."
        add_to_archive ${filename} ${dump_name}
        rm ${dump_name}
    done
}

backup_configs() {
    echo "Running config files backups..."
    if [[ -z ${BACKUP_DIR_CONFIGS} ]]; then
        BACKUP_DIR_CONFIGS=${BACKUP_DIR}
    fi
    mkdir_p ${BACKUP_DIR_CONFIGS}
    filename="${BACKUP_DIR_CONFIGS}/${BACKUP_DATE}-configs${BACKUP_EXT}"
    # The files to be saved need to be listed in a special variable.
    [[ -z ${BACKUP_FILES} ]] && \
        die "The files to be backed up are not specified."
    for file in "${BACKUP_FILES[@]}"; do
        add_to_archive ${filename} $file
    done
}

print_help() {
    cat <<EOF
backup.sh: a simple backup script.

Usage:
    backup.sh [flags]

Options:
-a | --all: run the default set of backups (configs and Docker as of now)
-p | --postgres: run the backups on PostgreSQL databases
-d | --docker: run the backups on Docker volumes
-c | --configs: run the backups on the files specified in /etc/backups.conf
--no-cleanup: don't cleanup after the backup has finished
EOF
}

case ${1} in
    "-a" | "--all")
        backup_configs
        backup_docker
        # backup_postgres
        # This is commented out by default, as PostgreSQL backups might be
        # preferable to run under a separate user.
        ;;
    "-h" | "--help")
        print_help
        BACKUP_NO_CLEANUP=1 # prevent cleanup on displaying help
        ;;
    *)
        while [[ ! -z ${1} ]]; do
            case ${1} in
                "-d" | "--docker")
                    backup_docker
                    ;;
                "-p" | "--postgres")
                    backup_postgres
                    ;;
                "-c" | "--configs")
                    backup_configs
                    ;;
                "--no-cleanup")
                    BACKUP_NO_CLEANUP=1
                    ;;
            esac
            shift
        done
        ;;
esac

if [[ -z ${BACKUP_NO_CLEANUP} ]]; then
    echo "Cleaning up..."
    # Run cleanup on every backup directory.
    for i in ${BACKUP_DIR} ${BACKUP_DIR_CONFIGS} ${BACKUP_DIR_DOCKER} \
        ${BACKUP_DIR_POSTGRES}; do
        [[ ! -z $i ]] && clean_up $i
    done
fi

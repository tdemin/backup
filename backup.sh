#!/usr/bin/env bash

__CONFIG_FILE="/etc/backups.conf"

# A simple wrapper for a Gentoo ebuild-like `die`.
die() {
    echo "$*" 1>&2
    exit 1
}

# Source the configuration file.
[[ -f ${__CONFIG_FILE} ]] || die "Cannot find ${__CONFIG_FILE}. Exiting."
source ${__CONFIG_FILE}
# Check the required / optional variables.
[[ -z ${__BACKUP_DIR} ]] && die "__BACKUP_DIR is not set."
[[ -z ${__BACKUP_EXT} ]] && __BACKUP_EXT=".tar.gz" # default compression format
[[ -z ${__BACKUP_AGE} ]] && __BACKUP_AGE=2 # 2 day-old backups stored by default
# Set the date to be inserted to tarball names.
__DATE="$(date +%Y-%m-%d-%H-%M)"

# Create the backup directory if it does not exist yet.
[[ ! -d ${__BACKUP_DIR} ]] && mkdir -p ${__BACKUP_DIR} && \
    echo "Created ${__BACKUP_DIR} for you."

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
    /usr/bin/env find "${__BACKUP_DIR}" -ctime +${__BACKUP_AGE} -delete || \
        die "Cleanup failed!"
}

backup_docker() {
    echo "Running a Docker volumes backup..."
    __FILENAME="${__BACKUP_DIR}/${__DATE}-docker${__BACKUP_EXT}"
    # Check the presence of the Docker directory.
    [[ -d /var/lib/docker ]] || die "Docker is likely to not be installed."
    empty_archive ${__FILENAME}
    add_to_archive ${__FILENAME} /var/lib/docker/volumes
}

backup_postgres() {
    echo "Running a PostgreSQL databases backup..."
    __FILENAME="${__BACKUP_DIR}/${__DATE}-postgres${__BACKUP_EXT}"
    # The databases need to be listed in a special variable.
    [[ -z ${__BACKUP_DATABASES} ]] && die "The databases list is not specified."
    for database in "${__BACKUP_DATABASES[@]}"; do
        __DUMP_NAME="${__FILENAME}-$database"
        pg_dump -Fc $database > ${__DUMP_NAME} || \
            die "Failed backing up database $database."
        add_to_archive ${__FILENAME} ${__DUMP_NAME}
        rm ${__DUMP_NAME}
    done
}

backup_configs() {
    echo "Running config files backups..."
    __FILENAME="${__BACKUP_DIR}/${__DATE}-configs${__BACKUP_EXT}"
    # The files to be saved need to be listed in a special variable.
    [[ -z ${__BACKUP_FILES} ]] && \
        die "The files to be backed up are not specified."
    for file in "${__BACKUP_FILES[@]}"; do
        add_to_archive ${__FILENAME} $file
    done
}

# Check if the first command-line flag is `-a` and run all of the options if
# applicable, check for the other flags otherwise.
if [[ "${1}" != "-a" ]]; then
    for arg in "$*"; do
        case $arg in
            "-d" | "--docker")
                backup_docker
                ;;
            "-p" | "--postgres")
                backup_postgres
                ;;
            "-c" | "--configs")
                backup_configs
                ;;
            "-a")
                die "-a cannot be specified after any other flags."
                ;;
            "$0")
                # This is only hit when listing through the basename.
                # Do nothing.
                ;;
        esac
    done
else
    backup_configs
    backup_docker
    # backup_postgres
fi
clean_up

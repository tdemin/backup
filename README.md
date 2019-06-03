## backup.sh

As the name suggests, this is a simple backup script written in bash.

This script came up as a result of rewriting a few backup scripts that
did their job yet shared like 90% of their code. The original scripts
were very hasty, so I tried to remade them into something a little more
presentable.

At this time this script is capable of dealing with backing up regular
files/directories and PostgreSQL databases. It has a separate Docker
volume backup option, but it's been mainly made to separate those from
configuration files.

This script is meant to be periodically run with cron/systemd timers.
It comes with example systemd units/timers made to do just that.

##### Usage

    backup.sh: a simple backup script.

    Usage:
        backup.sh [flags]

    Options:
    -a | --all: run the default set of backups (configs and Docker as of now)
    -p | --postgres: run the backups on PostgreSQL databases
    -d | --docker: run the backups on Docker volumes
    -c | --configs: run the backups on the files specified in /etc/backups.conf

##### Configuration options

The configuration file is located at `/etc/backups.conf`. It has to be a
valid bash script, as it's sourced at the program start.

For the available options see [the example config file](backups.conf.example).

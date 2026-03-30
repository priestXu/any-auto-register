#!/bin/sh
set -eu

mkdir -p /app/data /home/appuser/.cache

if [ "$(id -u)" = "0" ]; then
  chown -R appuser:appuser /app/data /home/appuser/.cache
  export HOME=/home/appuser
  export XDG_CACHE_HOME=/home/appuser/.cache
  exec gosu appuser "$@"
fi

export HOME="${HOME:-/home/appuser}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
exec "$@"

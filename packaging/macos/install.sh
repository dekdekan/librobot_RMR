#!/bin/sh
set -eu

prefix=/usr/local
package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this installer with permission to write ${prefix}." >&2
    exit 1
fi

for directory in bin lib include; do
    if [ -d "${package_dir}/${directory}" ]; then
        mkdir -p "${prefix}/${directory}"
        cp -R "${package_dir}/${directory}/." "${prefix}/${directory}/"
    fi
done

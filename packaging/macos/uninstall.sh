#!/bin/sh
set -eu

prefix=/usr/local

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this uninstaller with permission to write ${prefix}." >&2
    exit 1
fi

rm -f "${prefix}/bin"/liblibrobot*.dylib
rm -f "${prefix}/lib"/liblibrobot*.dylib
rm -f "${prefix}/lib"/liblibrobot*.a
rm -rf "${prefix}/include/librobot" "${prefix}/lib/cmake/librobot"

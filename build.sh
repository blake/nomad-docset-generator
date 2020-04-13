#!/usr/bin/env bash

set -ex

# Read parameters
TAG=$1
if [ -z "$TAG" ]; then
    echo '"TAG" must be specified'
    exit 1
fi

# Paths
CWD=$(pwd)
BUILD_PATH="${CWD}/build/$TAG"
NOMAD_PATH="${CWD}/nomad"
WEBSITE_PATH="${NOMAD_PATH}/website"

# Clean build
rm -rf "${BUILD_PATH}"
mkdir -p "${BUILD_PATH}"

# Checkout and clean
git clone "https://github.com/hashicorp/nomad.git" || true
cd "${NOMAD_PATH}"
git fetch --all --prune
git checkout -- .
git checkout "v${TAG}"

# Install gems
cd "${WEBSITE_PATH}"
npm install

# Build website
npm run static

rm Rakefile || true
ln -s "${CWD}/Rakefile" . || true

# Build
rake

mv Nomad.tgz "${BUILD_PATH}"

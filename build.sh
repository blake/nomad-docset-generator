#!/usr/bin/env bash

set -ex

function build_tag () {
    # Clean build
    BUILD_PATH="${CWD}/build/$1"
    rm -rf "${BUILD_PATH}"
    mkdir -p "${BUILD_PATH}"

    git fetch --all --prune
    git fetch --tags
    git checkout -- .
    git clean -d --force -x

    git checkout "${1}"

    # Convert redirects to JSON file so they can be evaluated during site build
    if [[ -f "${WEBSITE_PATH}/redirects.js" ]]; then
        "${CWD}/tools/redirects-to-json.js ${WEBSITE_PATH}/redirects.js" > "${WEBSITE_PATH}/redirects.json"
    fi

    cd "${WEBSITE_PATH}"

    # If package.json is not present
    if [[ ! -f "./package.json" ]]; then
        # Remove build directory and skip this release
        rmdir "${BUILD_PATH}"
        return
    fi

    npm ci

    # Build website
    npm run static

    rm Rakefile || true
    ln -s "${CWD}/Rakefile" . || true

    # Build
    rake

    mv Nomad.tgz "${BUILD_PATH}"
}

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
git fetch --tags
git checkout -- .
git clean -d --force -x
git checkout "v${TAG}"

# Convert redirects to JSON file so they can be evaluated during site build
if [[ -f "${WEBSITE_PATH}/redirects.json" ]]; then
    "${CWD}/tools/redirects-to-json.js" > "${WEBSITE_PATH}/redirects.json"
fi

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

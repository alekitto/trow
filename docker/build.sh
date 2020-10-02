#!/bin/bash

#change to directory with script so we know where project root is
#https://stackoverflow.com/questions/59895/can-a-bash-script-tell-which-directory-it-is-stored-in
src_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$src_dir"

# Github Package Repository doesn't support multi-arch images currently, so on hold
# Or pulls without authentication...
GH_REPO=${DOCKER_REPO:-"ghcr.io/alekitto/trow"}
REPO=${DOCKER_REPO:-"alekitto/trow"}

if [[ "$CI" = true ]]
then
    VERSION=$(date +"%Y-%m-%d")-$GITHUB_RUN_NUMBER
else
    VERSION=$(sed '/^version = */!d; s///;q' ../Cargo.toml | sed s/\"//g)
fi

TAG=${DOCKER_TAG:-"$VERSION-amd64"}
IMAGE=${IMAGE_NAME:-"$REPO:$TAG"}
DATE="$(date --rfc-3339=seconds)"

docker build \
  --build-arg VCS_REF="${SOURCE_COMMIT:-$(git rev-parse HEAD)}" \
  --build-arg VCS_BRANCH="${SOURCE_BRANCH:-$(git symbolic-ref --short HEAD)}" \
  --build-arg REPO="$REPO" \
  --build-arg TAG="$TAG" \
  --build-arg DATE="$DATE" \
  --build-arg VERSION="$VERSION" \
  -f Dockerfile -t $IMAGE ../

docker tag $IMAGE $REPO:default

if [[ "$CI" = true ]]
then

    docker push $IMAGE
    docker tag $IMAGE containersol/trow:default
    docker push containersol/trow:default

    # To run the Conformance tests in github actions, we need an image with --no-tls configured
    docker build -f Dockerfile.notls -t containersol/trow:notls ../
    docker push containersol/trow:notls

    docker tag $IMAGE containersol/trow:latest
    docker push containersol/trow:latest
    docker tag $IMAGE docker.pkg.github.com/containersolutions/trow/trow:default
    docker push docker.pkg.github.com/containersolutions/trow/trow:default

    # Add new image name to manifest template
    sed -i "s|{{TROW_AMD64_IMAGE}}|${IMAGE}|" ./manifest.tmpl
fi

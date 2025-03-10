#!/bin/bash

REPO=$(
  cd $(dirname $0)
  pwd
)
COMMIT_SHA=$(git rev-parse --short HEAD)
VERSION=$(git describe --tags)
ASSETS="false"
BINARY="false"
RELEASE="false"

debugInfo() {
  echo "Repo:           $REPO"
  echo "Build assets:   $ASSETS"
  echo "Build binary:   $BINARY"
  echo "Release:        $RELEASE"
  echo "Version:        $VERSION"
  echo "Commit:        $COMMIT_SHA"
}

buildAssets() {
  cd $REPO
  rm -rf assets/build

  export CI=false

  cd $REPO/assets

  yarn install
  yarn run build
  cd build
  find . -name "*.map" -type f -delete
  cd $REPO
  zip -r - assets/build >assets.zip
}

buildBinary() {
  cd $REPO
  go build -a -o cloudreve -ldflags " -s -w -extldflags '-static' -X 'github.com/cloudreve/Cloudreve/v3/pkg/conf.BackendVersion=$VERSION' -X 'github.com/cloudreve/Cloudreve/v3/pkg/conf.LastCommit=$COMMIT_SHA'"
}

_build() {
  local osarch=$1
  IFS=/ read -r -a arr <<<"$osarch"
  os="${arr[0]}"
  arch="${arr[1]}"
  gcc="${arr[2]}"

  # Go build to build the binary.
  export GOOS=$os
  export GOARCH=$arch
  export CC=$gcc
  export CGO_ENABLED=1
  export GOARM=7

  if [ -n "$VERSION" ]; then
    out="release/cloudreve_${VERSION}_${os}_${arch}"
  else
    out="release/cloudreve_${COMMIT_SHA}_${os}_${arch}"
  fi

  go build -a -o "${out}" -ldflags " -s -w -extldflags '-static' -X 'github.com/cloudreve/Cloudreve/v3/pkg/conf.BackendVersion=$VERSION' -X 'github.com/cloudreve/Cloudreve/v3/pkg/conf.LastCommit=$COMMIT_SHA'"

  if [ "$os" = "windows" ]; then
    mv $out release/cloudreve.exe
    zip -j -q "${out}.zip" release/cloudreve.exe
    rm -f "release/cloudreve.exe"
  else
    mv $out release/cloudreve
    tar -zcvf "${out}.tar.gz" -C release cloudreve
    rm -f "release/cloudreve"
  fi
}

release() {
  cd $REPO
  ## List of architectures and OS to test coss compilation.
  SUPPORTED_OSARCH="linux/arm/arm-linux-gnueabihf-gcc"

  echo "Release builds for OS/Arch/CC: ${SUPPORTED_OSARCH}"
  for each_osarch in ${SUPPORTED_OSARCH}; do
    _build "${each_osarch}"
  done
}

usage() {
  echo "Usage: $0 [-a] [-c] [-b] [-r]" 1>&2
  exit 1
}

while getopts "bacr:d" o; do
  case "${o}" in
  b)
    ASSETS="true"
    BINARY="true"
    ;;
  a)
    ASSETS="true"
    ;;
  c)
    BINARY="true"
    ;;
  r)
    ASSETS="true"
    RELEASE="true"
    ;;
  d)
    DEBUG="true"
    ;;
  *)
    usage
    ;;
  esac
done
shift $((OPTIND - 1))

if [ "$DEBUG" = "true" ]; then
  debugInfo
fi

if [ "$ASSETS" = "true" ]; then
  buildAssets
fi

if [ "$BINARY" = "true" ]; then
  buildBinary
fi

if [ "$RELEASE" = "true" ]; then
  release
fi

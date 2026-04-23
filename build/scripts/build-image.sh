#!/usr/bin/env sh
# Build Melange APKs and apko OCI tarball (no ECR push). Run from repository root.
# Requires: Docker, network access to ghcr.io and packages.wolfi.dev
set -eux

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

mkdir -p dist

docker run --privileged --rm \
  -v "${ROOT}:/work" \
  -w /work \
  ghcr.io/wolfi-dev/sdk:latest \
  sh -ceu '
    melange keygen /work/build/melange.rsa
    melange build /work/build/melange/fortress-exec.yaml \
      --signing-key /work/build/melange.rsa \
      --arch x86_64
    apko build /work/build/apko/fortress-exec.yaml \
      fortress-exec:local \
      /work/dist/fortress-exec.tar \
      --repository-append /work/packages \
      --keyring-append /work/build/melange.rsa.pub \
      --arch x86_64
  '

echo "Built: ${ROOT}/dist/fortress-exec.tar"

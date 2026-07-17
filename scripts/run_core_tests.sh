#!/bin/sh
set -eu

swift run \
  --scratch-path /tmp/coldsigner-swift-build \
  ColdSignerCoreTestRunner

#!/bin/bash

flags=""

if [[ "$ENABLE_YJIT" == "true" ]]; then
  echo "Enabling YJIT"
  flags+=" --yjit"
else
  echo "YJIT is not enabled. Enable by setting ENABLE_YJIT=true in fly.toml"
fi

exec /usr/bin/env ruby $flags $*

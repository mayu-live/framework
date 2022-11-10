#!/bin/bash

set -e

response=$(curl -s --http2-prior-knowledge http://localhost:3000/__mayu/status)
[[ "${response}" == "ok" ]]

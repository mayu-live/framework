#!/bin/bash

set -e

response=$(curl -fsS --http2-prior-knowledge http://localhost:3333/api/health)
[[ "${response}" == '{"status":"ok"}' ]]

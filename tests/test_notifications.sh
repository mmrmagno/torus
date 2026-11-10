#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -I tests/notifications/check.py

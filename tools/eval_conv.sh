#!/usr/bin/env bash
# Conversation eval against the host llama-server (127.0.0.1:8080).
# Usage: tools/eval_conv.sh <label>   (env: BZ_CONV_ONLY=g01,m01 BZ_CONV_PAR=2 BZ_EVAL_URL=...)
set -euo pipefail
export PATH="$HOME/development/flutter/bin:$PATH"
cd "$(dirname "$0")/../app"
export BZ_CONV_EVAL=1 BZ_CONV_LABEL="${1:?label}"
flutter test test/eval/conversation_eval_test.dart --reporter expanded

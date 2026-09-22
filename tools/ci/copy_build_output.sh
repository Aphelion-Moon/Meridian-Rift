#!/bin/bash
# APHELION EDIT ADDITION START - Missing native dependencies must fail artifact packaging.
set -euo pipefail
# APHELION EDIT ADDITION END

mkdir -p \
    $1/icons \
    $1/tgui/public \

cp tgstation.dmb tgstation.rsc $1/
# APHELION EDIT ADDITION START - Linux test worlds load this alongside their DMB.
cp libmeridian_painting_store.so "$1/"
# APHELION EDIT ADDITION END
cp -r icons/* $1/icons/
cp -r tgui/public/* $1/tgui/public/

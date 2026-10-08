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
# APHELION EDIT ADDITION START - The test job's sparse checkout has no modular folders, so the assets deploy.sh copies from them ride in the artifact.
find modular_nova/ -name '*.dmi' -exec cp --parents -t "$1" {} +
find modular_nova/modules/GAGS/json_configs modular_nova/modules/GAGS/nsfw/json_configs -name '*.json' -exec cp --parents -t "$1" {} +
find modular_aphelion/ -name '*.dmi' -exec cp --parents -t "$1" {} +
# APHELION EDIT ADDITION END

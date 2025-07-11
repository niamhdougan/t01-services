#!/bin/bash

# CI to verify all the instances specified in this repo have valid configs.
# The intention here is to verify that any mounted config folder will work
# with the container image specified in values.yaml
#
# At present this will only work with IOCs because it uses ibek. To support
# other future services that don't use ibek, we will need to add a standard
# entrypoint for validating the config folder mounted at /config.

ROOT=$(realpath $(dirname ${0})/../..)
set -xe


# use docker if available else use podman
if ! docker version &>/dev/null; then docker=podman; else docker=docker; fi

for service in ${ROOT}/services/*
do
    # Skip if subfolder has no config to validate
    if [ ! -f "${service}/config/ioc.yaml" ]; then
        continue
    fi

    # Get the container image that this service uses from values.yaml if supplied
    image=$(cat ${service}/compose.yml | sed -rn 's/^ +image: (.*)/\1/p')

    if [ -n "${image}" ]; then
        echo "Validating ${service} with ${image}"

        runtime=/tmp/ioc-runtime/$(basename ${service})
        mkdir -p ${runtime}

        # avoid issues with auto-gen genicam pvi files (ioc-adaravis only)
        sed -i s/AutoADGenICam/ADGenICam/ ${service}/config/ioc.yaml

        # This will fail and exit if the ioc.yaml is invalid
        $docker run --rm --entrypoint bash \
            --security-opt label=disable \
            -v ${service}/config:/config \
            -v ${runtime}:/epics/runtime \
            ${image} \
            -c 'ibek runtime generate /config/ioc.yaml /epics/ibek-defs/*.ibek.support.yaml'
        # show the startup script we just generated (and verify it exists)
        cat  ${runtime}/st.cmd

    fi
done

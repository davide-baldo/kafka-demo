#!/usr/bin/env bash

set -ex
set -m

if ockam identity show sidecar >/dev/null 2>&1; then
  echo "Identity already enrolled"
else
  ockam identity create sidecar
  ockam project enroll "${ENROLL_TOKEN}" --identity sidecar
fi

# You want to start afresh each time, only the identity needs to survive
ockam node delete sidecar || true

if [ "${ROLE}" == "outlet" ]; then
  ockam node create sidecar --foreground -v --identity sidecar --tcp-listener-address 0.0.0.0:${OUTLET_PORT} &
else
  ockam node create sidecar --foreground -v --identity sidecar &
fi

## To let the foreground node start
sleep 2

## To ping the node
ockam node list

if [ "${ROLE}" == "outlet" ]; then
  ockam kafka-outlet create -v --node sidecar --bootstrap-server ${BOOTSTRAP_SERVER}
else
  ockam kafka-${ROLE} create -v --node sidecar --bootstrap-server ${BOOTSTRAP_SERVER_LISTENER} --project-route /dnsaddr/${OUTLET_HOST}/tcp/${OUTLET_PORT}/secure/api
fi
fg %1

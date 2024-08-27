#!/bin/bash

##############################################################################
#
# This script will return 0 if the underlying application process is
# started.  This is primarily intended for use in environments that
# provide an application startup probe, in particular the Kubernetes
# `startupProbe` and `readinessProbe` hooks. See
# https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/
# for more information.
#
##############################################################################

. /probe-common.sh

# This is currently the same as `probe-readiness.sh`, as we have no
# consistent way to ensure the agent is available (as opposed to just
# the JVM running). See that script for details of the checks made.

if [[ "$BAMBOO_AGENT_PERMISSIVE_READINESS" == "true" ]]; then
    grep -q STARTED ${WRAPPER_STATUSFILE} \
         || grep -q STARTING ${WRAPPER_STATUSFILE}
else
    grep -q STARTED ${WRAPPER_STATUSFILE} \
        && grep -q STARTED ${JAVA_STATUSFILE}
fi

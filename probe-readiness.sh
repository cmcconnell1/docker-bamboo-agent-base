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

# The Bamboo uses a wrapper process to start the agent, and restart it
# on failure. The wrapper generates status files for itself and the
# underlying application, so we can use this for the basic status. See
# https://wrapper.tanukisoftware.com/doc/english/prop-statusfile.html,
# https://wrapper.tanukisoftware.com/doc/english/prop-java-statusfile.html
# and `bamboo-agent.sh` for details.
#
# If the Java process crashes it will be restarted by the wrapper; in
# that case the Java status will change and the readiness will be
# paused. Additionally, if the environment variable
# `BAMBOO_AGENT_PERMISSIVE_READINESS` is set to 'true', the readiness
# probe will be more permissive and not expect the agent to be fully
# configured. This is primarily intended for use when deploying agents
# into environments where the server may not yet be configured.

if [[ "$BAMBOO_AGENT_PERMISSIVE_READINESS" == "true" ]]; then
    grep -q STARTED ${WRAPPER_STATUSFILE} \
         || grep -q STARTING ${WRAPPER_STATUSFILE}
else
    grep -q STARTED ${WRAPPER_STATUSFILE} \
        && grep -q STARTED ${JAVA_STATUSFILE}
fi

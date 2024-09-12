#!/bin/bash -l
set -x

# Check if the public certificate has already been imported and import to java keystore if not
# this requires a k8s secret to exist for the public key
# kubectl -n my-namespace create secret generic publickey --from-file=publickey.pem=/path/to/publickey.pem
# NOTE: make sure to mount the secret to the container and set the path to the public key file in you pod spec
# in our case the public cert is a k8s secret and is mounted as a file /etc/ssl/certs/publickey.pem in the ephemeral bamboo agent container
if [ ! -f /first_run_done ]; then
    keytool -import -trustcacerts -alias publickey -file /etc/ssl/certs/publickey.pem -keystore $JAVA_HOME/lib/security/cacerts -storepass changeit -noprompt
    touch /first_run_done
fi
 
KUBE_NUM_EXTRA_CONTAINERS_OR_ZERO="${KUBE_NUM_EXTRA_CONTAINERS:=0}"

if [ -d "$BAMBOO_AGENT_CLASSPATH_DIR" ]
then
  for SUBDIR in classpath plugins framework-bundles
  do
    cp -R "$BAMBOO_AGENT_CLASSPATH_DIR/$SUBDIR" "$BAMBOO_AGENT_HOME/$SUBDIR"
    chown -R $RUN_USER "$BAMBOO_AGENT_HOME/$SUBDIR"
    chmod -R u+w "$BAMBOO_AGENT_HOME/$SUBDIR"
  done
fi

if [[ -d "$EXTRA_CONTAINERS_REGISTRATION_DIRECTORY" && $KUBE_NUM_EXTRA_CONTAINERS_OR_ZERO -ne 0 ]]; then
    retries=0
    # 30 retries per minute times 20 minutes = loop 600 times
    # it's so high because of docker downloads of side containers.
    CONTAINER_START_RETRY_COUNT=600
    echo "Waiting for $KUBE_NUM_EXTRA_CONTAINERS_OR_ZERO side containers to start"
    while true; do
        if [ $retries -eq $CONTAINER_START_RETRY_COUNT ]; then
            echo "Side containers failed to create file(s) in $EXTRA_CONTAINERS_REGISTRATION_DIRECTORY"
            ls -la "$EXTRA_CONTAINERS_REGISTRATION_DIRECTORY"
            break
        elif [ "$(find "$EXTRA_CONTAINERS_REGISTRATION_DIRECTORY" -type f| wc -l)" -ne "$KUBE_NUM_EXTRA_CONTAINERS_OR_ZERO" ]; then
            echo "No match, waiting some more"
            sleep 2
            let retries=retries+1
        else
            echo "all side containers have started"
            break
        fi
    done
fi

exec "$@"

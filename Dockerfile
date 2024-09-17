ARG BASE_IMAGE=openjdk:17-jdk-bullseye
FROM $BASE_IMAGE

# docker build --platform linux/amd64  --build-arg BAMBOO_VERSION=9.5.2  -t cmcc123/docker-bamboo-agent-base:dind . ; docker push cmcc123/docker-bamboo-agent-base:dind
LABEL maintainer="foo@updateme.com"
LABEL securitytxt="https://www.atlassian.com/.well-known/security.txt"

ENV APP_NAME                                bamboo_agent
ENV RUN_USER                                 bamboo
ENV RUN_GROUP                                bamboo
ENV RUN_UID                                  2005
ENV RUN_GID                                  2005

ENV BAMBOO_AGENT_HOME                        /var/atlassian/application-data/bamboo-agent
ENV BAMBOO_AGENT_INSTALL_DIR                 /opt/atlassian/bamboo
ENV KUBE_NUM_EXTRA_CONTAINERS                0
ENV EXTRA_CONTAINERS_REGISTRATION_DIRECTORY  /pbc/kube
ENV DISABLE_AGENT_AUTO_CAPABILITY_DETECTION  false

WORKDIR $BAMBOO_AGENT_HOME

COPY entrypoint.py \
     probe-common.sh \
     probe-startup.sh \
     probe-readiness.sh \
     pre-launch.sh \
     shared-components/image/entrypoint_helpers.py  /
COPY shared-components/support                      /opt/atlassian/support
COPY config/*                                       /opt/atlassian/etc/

ENV JAVA_OPTS="-Djavax.net.ssl.trustStore=$JAVA_HOME/lib/security/cacerts -Djavax.net.ssl.trustStorePassword=changeit"

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
         git git-lfs \
         openssh-client \
         python3 python3-jinja2 python-is-python3 \
         tini \
         maven \
         apt-transport-https \
         ca-certificates \
         curl \
         gnupg2 \
         lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         docker-ce-cli docker-ce containerd.io \
    && apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

ENV DOCKER_TLS_CERTDIR=/certs
VOLUME /var/lib/docker
VOLUME /certs/client
ENV DOCKER_DRIVER=overlay2

ARG MAVEN_VERSION=3.6.3
ENV MAVEN_HOME /opt/maven

RUN mkdir -p ${MAVEN_HOME} \
    && curl -L --silent https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz | tar -xz --strip-components=1 -C "${MAVEN_HOME}" \
    && ln -s ${MAVEN_HOME}/bin/mvn /usr/local/bin/mvn

ARG BAMBOO_VERSION
ENV BAMBOO_VERSION ${BAMBOO_VERSION}
ARG DOWNLOAD_URL=https://packages.atlassian.com/mvn/maven-atlassian-external/com/atlassian/bamboo/atlassian-bamboo-agent-installer/${BAMBOO_VERSION}/atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar
ARG DOWNLOAD_USERNAME
ARG DOWNLOAD_PASSWORD

COPY bamboo-update-capability.sh /

RUN groupadd --gid ${RUN_GID} ${RUN_GROUP} \
    && useradd --uid ${RUN_UID} --gid ${RUN_GID} --home-dir ${BAMBOO_AGENT_HOME} --shell /bin/bash ${RUN_USER} \
    && echo PATH=$PATH > /etc/environment \
    && mkdir -p ${BAMBOO_AGENT_INSTALL_DIR} \
    && chown -R ${RUN_USER}:root ${BAMBOO_AGENT_INSTALL_DIR} \
    && if [ -n "${DOWNLOAD_USERNAME}" ] && [ -n "${DOWNLOAD_PASSWORD}" ]; then \
        curl -u ${DOWNLOAD_USERNAME}:${DOWNLOAD_PASSWORD} -L --fail --silent --show-error ${DOWNLOAD_URL} -o "${BAMBOO_AGENT_INSTALL_DIR}/atlassian-bamboo-agent-installer.jar"; \
    else \
        curl -L --fail --silent --show-error ${DOWNLOAD_URL} -o "${BAMBOO_AGENT_INSTALL_DIR}/atlassian-bamboo-agent-installer.jar"; \
    fi \
    && if jar -tf "${BAMBOO_AGENT_INSTALL_DIR}/atlassian-bamboo-agent-installer.jar" > /dev/null 2>&1; then \
        echo "JAR file is valid"; \
    else \
        echo "JAR file is corrupted or missing"; \
        exit 1; \
    fi \
    && mkdir -p ${BAMBOO_AGENT_HOME}/conf ${BAMBOO_AGENT_HOME}/bin \
    && JAVA_MAJOR_VERSION=17 \
    && JAVA_MINOR_VERSION=12 \
    && /bamboo-update-capability.sh "JDK" ${JAVA_HOME}/bin/java \
    && /bamboo-update-capability.sh "system.jdk.JDK ${JAVA_MAJOR_VERSION}" ${JAVA_HOME}/bin/java \
    && /bamboo-update-capability.sh "system.jdk.JDK ${JAVA_MAJOR_VERSION}.${JAVA_MINOR_VERSION}" ${JAVA_HOME}/bin/java \
    && /bamboo-update-capability.sh "JDK ${JAVA_MAJOR_VERSION}" ${JAVA_HOME}/bin/java \
    && /bamboo-update-capability.sh "Python" /usr/bin/python3 \
    && /bamboo-update-capability.sh "Python 3" /usr/bin/python3 \
    && /bamboo-update-capability.sh "Git" /usr/bin/git \
    && /bamboo-update-capability.sh "system.builder.mvn3.Maven 3.3" /usr/local/bin/mvn \
    && chown -R ${RUN_USER}:root ${BAMBOO_AGENT_HOME} \
    && chmod -R 770 ${BAMBOO_AGENT_HOME} \
    && for file in /opt/atlassian/support /entrypoint.py /entrypoint_helpers.py /probe-common.sh /probe-startup.sh /probe-readiness.sh /pre-launch.sh /bamboo-update-capability.sh; do \
        chmod -R "u=rwX,g=rX,o=rX" ${file} && \
        chown -R root ${file}; \
    done

COPY --from=docker:23.0.1-dind /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/dockerd-entrypoint.sh
RUN chmod +x /usr/local/bin/dockerd-entrypoint.sh

CMD ["/usr/local/bin/dockerd-entrypoint.sh"]

ENTRYPOINT ["/pre-launch.sh"]

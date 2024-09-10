A Bamboo Agent is a service that can run job builds. Each agent has a defined set of capabilities and can run builds only for jobs whose requirements match the agent's capabilities.
To learn more about Bamboo, see: https://www.atlassian.com/software/bamboo

If you are looking for **Bamboo Server Docker Image** it can be found [here](https://hub.docker.com/r/atlassian/bamboo/).

# Overview

This Docker container makes it easy to get a Bamboo Remote Agent up and running. It is intended to be used as a base to build from, and as such
contains limited built-in capabilities:

* JDK 11 (JDK 17 starting from v9.4.0)
* Git & Git LFS
* Maven 3
* Python 3

Using this image as a base, you can create a custom remote agent image with your
desired build tools installed. Note that Bamboo Agent Docker Image does not
include a Bamboo server.

**Use docker version >= 20.10.9.**

# Available Ubuntu base versions
This image is based on [Eclipse Temurin](https://hub.docker.com/_/eclipse-temurin) and ships with Ubuntu 24.04 (Noble).
For users requiring the earlier Ubuntu Jammy (22.04) version, the `jdk11-jammy` and `jdk17-jammy` tags are available.

**Note:** The `-jammy` tags are not maintained and are provided solely for compatibility and migration purposes. 
It is strongly recommended to use the latest `jdk11` or `jdk17` tags in production environments to ensure you receive the latest updates and security patches.

# Quick Start

For the `BAMBOO_AGENT_HOME` directory that is used to store the repository data (amongst other things) we recommend mounting a host directory as a [data volume](https://docs.docker.com/engine/tutorials/dockervolumes/#/data-volumes), or via a named volume.

To get started you can use a data volume, or named volumes. In this example we'll use named volumes.

Run an Agent:

    $> docker volume create --name bambooAgentVolume
    $> docker run -e BAMBOO_SERVER=http://bamboo.mycompany.com/agentServer/ -v bambooAgentVolume:/var/atlassian/application-data/bamboo-agent --name="bambooAgent" --hostname="bambooAgent" -d atlassian/bamboo-agent-base

**Success**. The Bamboo remote agent is now available to be approved in your Bamboo administration.

# Advanced Usage
For advanced usage, e.g. configuration, troubleshooting, supportability, etc.,
please check the [**Full Documentation**](https://atlassian.github.io/data-center-helm-charts/containers/BAMBOO-AGENT/).


# k8s-based builds--Note: bad idea, don't do this 
- insert many security, etc. concerns here...
## Skaffold and Kaniko for k8s-based builds
- If you must do this in k8s, here's how to create the necessary Skaffold and Kaniko configuration files to build a container 
- in this case we need to configure and build the `docker-bamboo-agent-base` project.

### 1. **Skaffold Configuration (skaffold.yaml)**

Skaffold is used to manage the lifecycle of container builds and deployments. Below is a basic `skaffold.yaml` configuration that integrates with Kaniko for building the Docker image.

```yaml
apiVersion: skaffold/v2beta29
kind: Config
metadata:
  name: bamboo-agent-build
build:
  artifacts:
    - image: bamboo-agent-base:latest
      context: .
      kaniko:
        buildContext:
          # Specify where to store intermediate layers (typically in Google Cloud Storage or S3)
          gcsBucket: skaffold-kaniko-bucket
        dockerfilePath: Dockerfile
        cache: # Optional: to enable caching
          cacheRepo: <gcr-docker-repo>
deploy:
  kubectl:
    manifests:
      - k8s/deployment.yaml
```

### 2. **Kaniko Configuration (Kaniko Docker Build using Kubernetes)**

Kaniko is run inside Kubernetes to build Docker images without Docker-in-Docker (DinD). For this, you’ll need a Kubernetes `Job` definition that runs the Kaniko build process.

Create a `k8s/kaniko-job.yaml` file with the following content:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-build-job
spec:
  backoffLimit: 0
  template:
    spec:
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - "--context=git://github.com/cmcconnell1/docker-bamboo-agent-base.git#main"
            - "--dockerfile=Dockerfile"
            - "--destination=<your-docker-registry>/bamboo-agent-base:latest"
            - "--cache=true"
          volumeMounts:
            - name: kaniko-secret
              mountPath: /secret
      restartPolicy: Never
      volumes:
        - name: kaniko-secret
          secret:
            secretName: regcred
```

### 3. **Kubernetes Secret for Docker Registry (regcred.yaml)**

You will need to create a Kubernetes secret that contains credentials for your Docker registry. For example:

```bash
kubectl create secret docker-registry regcred \
  --docker-server=<your-docker-registry> \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --docker-email=<your-email>
```

Or define it in YAML:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: regcred
data:
  .dockerconfigjson: <base64-encoded-docker-config>
type: kubernetes.io/dockerconfigjson
```

### 4. **Kubernetes Deployment (deployment.yaml)**

Once the container is built, you can deploy it into your Kubernetes cluster. Create a `k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bamboo-agent-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bamboo-agent
  template:
    metadata:
      labels:
        app: bamboo-agent
    spec:
      containers:
        - name: bamboo-agent
          image: <your-docker-registry>/bamboo-agent-base:latest
          ports:
            - containerPort: 8085
```

### Steps:

1. **Install Skaffold**:  
   Install Skaffold using:
   ```bash
   curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
   chmod +x skaffold
   sudo mv skaffold /usr/local/bin
   ```

2. **Run Skaffold**:  
   After setting up the files, run:
   ```bash
   skaffold dev
   ```

This will build and deploy the `docker-bamboo-agent-base` project in your Kubernetes cluster using Kaniko as the build engine.

Let me know if you need help with further customization!
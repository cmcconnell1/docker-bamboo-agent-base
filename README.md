### Developer Onboarding Guide for Docker-Based Applications in Atlassian Bamboo 9.5.2

### Overview
- This document provides step-by-step instructions for onboarding application teams Docker-based applications and getting the docker containers built using Atlassian Bamboo with a remote git repository as the build source.  The setup includes using Docker-in-Docker (DinD) for building Docker images.
- Within Bamboo you will 
    - configure a Bamboo project
    - create a build plan, and
    - set up an ephemeral agent with a custom Docker image--based on [docker-bamboo-agent-base](https://github.com/cmcconnell1/docker-bamboo-agent-base). 

---

### Table of Contents
1. **Pre-requisites**
2. **Overview of Docker in Docker (DinD)**
3. **Forking the Bamboo Agent Base Docker Image**
4. **Setting Up Bamboo Project and Plan**
5. **Configuring Bamboo Ephemeral Agent**
6. **Building Docker Images with Bamboo**
7. **Best Agent Configuration for Docker Image Builds**

---

### 1. Pre-requisites

- Access to Atlassian Bamboo (currently targeting version 9.5.2)
- A git (Bitbucket) repository with a `Dockerfile` for your application
- A fork of the [docker-bamboo-agent-base](https://github.com/cmcconnell1/docker-bamboo-agent-base) to customize the agent with your required dependencies.
- Working knowledge of Docker and Bamboo build agents not required but would be very helpful.

### 2. Overview of Docker in Docker (DinD)

**Docker-in-Docker (DinD)** is a method that allows a Docker container to run Docker commands within itself. For your Bamboo build pipeline, DinD is required because:
- Bamboo agents run inside Docker containers (in Kubernetes or remote environments).
- The Bamboo agent container needs to run Docker commands to build images.
- DinD avoids the need to install Docker directly on the host system by creating a clean, isolated environment inside the container.

**Why DinD is necessary:**
- It provides isolation between builds, ensuring each build has its own Docker daemon instance.
- Reduces conflicts between host and container Docker processes.
- Ensures that containers can spawn child containers, allowing Bamboo agents to build and push Docker images.

### 3. Forking the Bamboo Agent Base Docker Image

1. **Fork the Repository**: Fork the [docker-bamboo-agent-base](https://github.com/cmcconnell1/docker-bamboo-agent-base) to your own Bitbucket or GitHub account.
2. **Modify the Dockerfile**:
   - Add any necessary dependencies or tools required for your project.
   - The dependencies will depend upon the application and frameworks, but could include installing additional CLI tools, package managers, or specific libraries--e.g.: mvn, python, git, etc.

3. **Enable Docker-in-Docker (DinD)**:
   - In the Dockerfile, ensure that Docker is installed and that the agent runs in DinD mode by setting up the `docker` service within the container.
   - Example:
     ```Dockerfile
     FROM docker:20.10 as base
     RUN apk add --no-cache bash curl git
     # Additional dependencies for your project
     
     # Set up Docker-in-Docker
     RUN apk add --no-cache docker openrc
     ```

4. **Build and Push the Custom Agent**:
   - Build the Docker image for your custom agent.
     ```bash
     docker build -t your-custom-bamboo-agent:latest .
     ```
   - Push it to your container registry (e.g., Docker Hub, AWS ECR):
     ```bash
     docker push your-registry/your-custom-bamboo-agent:latest
     ```

### 4. Setting Up Bamboo Project and Plan

1. **Create a New Project in Bamboo**:
   - Navigate to **Create > Create Project** in Bamboo.
   - Set the project name and key.

2. **Create a Plan**:
   - Under the newly created project, select **Create Plan**.
   - Choose a plan name and select the **Bitbucket Repository** where your Docker-based application is stored.
   - Ensure the `Dockerfile` is in the root of the repository or in a specified directory Bamboo can access.

3. **Plan Stages and Jobs**:
   - Add a **Job** to your plan that will execute the Docker build process.
   - Set up tasks such as:
     - **Source Code Checkout**: To pull the repository from Bitbucket.
     - **Docker Build Task**: A custom script task that builds the Docker image.
     - **Docker Push Task**: Push the image to your container registry.

### 5. Configuring Bamboo Ephemeral Agent

1. **Set Up Ephemeral Kubernetes-Based Agent**:
   - Ephemeral agents are created and destroyed for each build, ensuring a clean environment.
   - Configure Bamboo to use your custom Docker agent by adding the agent image in your Kubernetes configuration.
     - Example YAML:
       ```yaml
       apiVersion: v1
       kind: Pod
       metadata:
         name: bamboo-ephemeral-agent
       spec:
         containers:
         - name: bamboo-agent
           image: your-registry/your-custom-bamboo-agent:latest
           securityContext:
             privileged: true  # Required for DinD
           volumeMounts:
           - mountPath: /var/run/docker.sock
             name: docker-socket
         volumes:
         - name: docker-socket
           hostPath:
             path: /var/run/docker.sock
       ```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: '{{NAME}}'
  namespace: gis-dev-bamboo
  labels:
    '{{RESOURCE_LABEL}}': bamboo-eph
spec:
  containers:
    - image: cmcc123/docker-bamboo-agent-base:java17
      name: '{{BAMBOO_AGENT_CONTAINER_NAME}}'
      imagePullPolicy: Always
      env:
        - name: BAMBOO_EPHEMERAL_AGENT_DATA
          value: '{{BAMBOO_EPHEMERAL_AGENT_DATA_VAL}}'
      volumeMounts:
        - name: public-key-volume
          mountPath: /etc/ssl/certs/publickey.pem
          subPath: publickey.pem
  volumes:
    - name: public-key-volume
      secret:
        secretName: bamboo-public-key
  restartPolicy: Never
contexts:
- context:
    cluster: gis-dev-eks02
    namespace: gis-dev-bamboo






2. **Configure Kubernetes Runner**:
   - Set up Bamboo to launch the ephemeral agents in your Kubernetes environment. Use the Docker agent you just built and ensure that it has access to the Docker socket for DinD functionality.

### 6. Building Docker Images with Bamboo

1. **Configure Docker Build Command**:
   In the Bamboo plan, configure a script task that performs the Docker build and push:
   ```bash
   docker build -t your-registry/your-app:${bamboo.buildNumber} .
   docker push your-registry/your-app:${bamboo.buildNumber}
   ```

2. **Handle Docker Permissions**:
   - Ensure that the Bamboo agent has permissions to build and push Docker images.
   - Verify access to the Docker socket or configure it via a DinD setup as outlined earlier.

### 7. Best Agent Configuration for Docker Image Builds

**Recommended Approach**: Use a **Kubernetes-based ephemeral agent** running in a container with Docker-in-Docker (DinD) enabled. This is the best approach because:
- Ephemeral agents offer clean, isolated environments for each build.
- Kubernetes provides scalability, allowing multiple builds to run in parallel.
- Docker-in-Docker ensures that the agent container can run Docker commands without conflicting with the host system.
- This approach avoids the need for persistent agents or manual configuration on hosts.

---

### Conclusion

By following these steps, your team can set up a robust and scalable build pipeline using Atlassian Bamboo 9.5.2 with Docker-based applications. Using Kubernetes-based ephemeral agents running Docker-in-Docker ensures clean, consistent, and efficient builds, while also reducing the complexity of managing agent environments.


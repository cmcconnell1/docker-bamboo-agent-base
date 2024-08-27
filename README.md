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


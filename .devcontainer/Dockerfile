#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

FROM google/dart:2.8.1


# Docker script args, location, and expected SHA - SHA generated on release
ARG DOCKER_SCRIPT_SOURCE="https://raw.githubusercontent.com/microsoft/vscode-dev-containers/v0.117.0/script-library/docker-debian.sh"
ARG DOCKER_SCRIPT_SHA="23a9e56a563e66a7339c43a67719fda06e70ce4d1fa2a870392e32a57aa42136"
ARG ENABLE_NONROOT_DOCKER="true"
ARG SOURCE_SOCKET=/var/run/docker-host.sock
ARG TARGET_SOCKET=/var/run/docker.sock

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Add bin location to path
ENV PATH="$PATH":"/root/.pub-cache/bin"

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
      apt-transport-https \
      build-essential \
      ca-certificates \
      curl \
      libssl-dev \
      wget \
      apt-utils \
      dialog \
      2>&1 \
    #
    # Verify git, process tools, lsb-release (common in install instructions for CLIs) installed
    && apt-get -y install git openssh-client less iproute2 procps lsb-release \
    # Install nodejs
    && curl -sL https://deb.nodesource.com/setup_10.x | bash - \
    && apt-get install -y nodejs \
    && npm i -g nodemon \
    && nodejs -v \
    && npm -v \
    #
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    #
    # Use Docker script from script library to set things up
    && curl -sSL $DOCKER_SCRIPT_SOURCE -o /tmp/docker-setup.sh \
    && if [ "$DOCKER_SCRIPT_SHA" != "dev-mode" ]; then echo "$DOCKER_SCRIPT_SHA /tmp/docker-setup.sh" | sha256sum -c - ; fi \
    && /bin/bash /tmp/docker-setup.sh "${ENABLE_NONROOT_DOCKER}" "${SOURCE_SOCKET}" "${TARGET_SOCKET}" "${USERNAME}" \
    && rm /tmp/docker-setup.sh \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz \
    # Install the gcloud package
    && mkdir -p /usr/local/gcloud \
    && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
    && /usr/local/gcloud/google-cloud-sdk/install.sh --quiet

# Adding the package path to local
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

# Install kubectl and make sure gcloud is up to date
RUN gcloud components install kubectl \
  && gcloud components update --quiet

# Copy localhost's ~/.kube/config file into the container and swap out localhost
# for host.docker.internal whenever a new shell starts to keep them in sync.
# RUN echo '\n\
# if [ "$SYNC_LOCALHOST_KUBECONFIG" == "true" ]; then\n\
#     mkdir -p $HOME/.kube\n\
#     cp -r $HOME/.kube-localhost/* $HOME/.kube\n\
#     sed -i -e "s/localhost/host.docker.internal/g" $HOME/.kube/config\n\
# \n\
# fi' \
# >> $HOME/.bashrc

# # Copy gcloud config from the host
# RUN echo '\n\
# if [ "$SYNC_LOCALHOST_GCLOUD" == "true" ]; then\n\
#     mkdir -p $HOME/.config/gcloud\n\
#     cp -r $HOME/.gcloud-localhost/* $HOME/.config/gcloud\n\
# \n\
# fi' \
# >> $HOME/.bashrc

# #COPY sync.sh /root/sync.sh
# #RUN touch /root/.bashrc && /root/sync.sh >> $HOME/.bashrc
# RUN echo '\n\
# if [ "$SYNC_LOCALHOST_SSH" == "true" ]; then\n\
#     mkdir -p ~/.ssh\n\
#     cp -r ~/.ssh-localhost/* ~/.ssh\n\
#     chmod 700 ~/.ssh \n\
#     chmod 600 ~/.ssh/*\n\
# fi' \
# >> $HOME/.bashrc

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog

# Setting the ENTRYPOINT to docker-init.sh will configure non-root access to 
# the Docker socket if "overrideCommand": false is set in devcontainer.json. 
# The script will also execute CMD if you need to alter startup behaviors.
ENTRYPOINT [ "/usr/local/share/docker-init.sh" ]
CMD [ "sleep", "infinity" ]
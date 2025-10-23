# Use Debian 12 as base
FROM debian:12

# Install required build tools for Debian packages
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
       build-essential dpkg-dev debhelper fakeroot lintian \
       gnupg2 git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user matching host UID/GID (will be overridden by devcontainer “updateRemoteUserUID”)
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update && apt-get install -y sudo \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set non-root user by default
USER $USERNAME
WORKDIR /home/$USERNAME

# (Optional) any post-install steps for your environment


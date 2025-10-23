# Use Debian 12 as base
FROM debian:12

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# Install required build tools for Debian packages
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        build-essential dpkg-dev debhelper fakeroot lintian \
        gnupg2 git sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user matching host UID/GID (will be overridden by devcontainer “updateRemoteUserUID”)
RUN set -eux; \
    if ! getent group "$USERNAME" >/dev/null; then \
        groupadd --gid "$USER_GID" --non-unique "$USERNAME"; \
    fi; \
    if ! id -u "$USERNAME" >/dev/null 2>&1; then \
        useradd --uid "$USER_UID" --gid "$USER_GID" --non-unique -m "$USERNAME"; \
    fi; \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME; \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Set non-root user by default
USER $USERNAME
WORKDIR /home/$USERNAME

# (Optional) any post-install steps for your environment

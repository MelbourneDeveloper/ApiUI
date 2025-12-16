# Pinned versions - last updated 2025-12-06
# Base image: mcr.microsoft.com/devcontainers/base:1.2.4-ubuntu-24.04
# Python: 3.12 (latest 3.12.x from deadsnakes)
# Flutter: 3.38.1 (stable)

FROM mcr.microsoft.com/devcontainers/base:1.2.4-ubuntu-24.04

# Install Python 3.12 from deadsnakes PPA
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip \
    pipx \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python linting/formatting tools globally via pipx
ENV PIPX_HOME=/opt/pipx
ENV PIPX_BIN_DIR=/usr/local/bin
RUN pipx install ruff \
    && pipx install pyright

# Install Flutter dependencies
RUN apt-get update && apt-get install -y \
    coreutils \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-13-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter 3.38.1 as vscode user
USER vscode
ENV HOME=/home/vscode
WORKDIR /home/vscode

ARG FLUTTER_VERSION=3.38.1
RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_VERSION} --depth 1 /home/vscode/.flutter
ENV PATH="/home/vscode/.flutter/bin:${PATH}"

# Configure Flutter (precache runs on first use)
RUN git config --global --add safe.directory /home/vscode/.flutter \
    && flutter config --no-analytics

USER root
RUN git config --global --add safe.directory /home/vscode/.flutter
WORKDIR /workspaces

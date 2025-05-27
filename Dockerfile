# Docker container for Xilinx development environment
FROM ubuntu:20.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    bc \
    mailutils \
    tar \
    gzip \
    vim \
    sudo \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install Python packages
RUN pip3 install \
    matplotlib \
    pandas \
    numpy \
    scipy \
    jupyter \
    pytest

# Create vivado user
RUN useradd -m -s /bin/bash vivado && \
    echo "vivado ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to vivado user
USER vivado
WORKDIR /home/vivado

# Create workspace directory
RUN mkdir -p /home/vivado/workspace

# Copy project files
COPY --chown=vivado:vivado . /home/vivado/workspace/

# Set working directory
WORKDIR /home/vivado/workspace

# Expose ports for Jupyter and web dashboard
EXPOSE 8888 8080

# Default command
CMD ["/bin/bash"]

# RTL-SDR AFSK1200 Decoder Dockerfile
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    rtl-sdr \
    multimon-ng \
    sox \
    python3 \
    python3-pip \
    git \
    build-essential \
    cmake \
    librtlsdr-dev \
    libusb-1.0-0-dev \
    pkg-config \
    libasound2-dev \
    udev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Clone, build, and install Direwolf (APRS decoder)
RUN git clone https://github.com/wb2osz/direwolf.git /tmp/direwolf && \
    cd /tmp/direwolf && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j4 && \
    make install && \
    cd / && \
    rm -rf /tmp/direwolf

# Install Python packages
RUN pip3 install \
    numpy \
    scipy \
    matplotlib \
    pandas

# Copy project files to container
COPY . /app/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Set environment variables for Python
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Default command opens bash shell
CMD ["bash"]

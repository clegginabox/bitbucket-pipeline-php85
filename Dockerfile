FROM php:8.5-cli

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    unzip \
    git \
    zip \
    curl \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    default-mysql-client \
    cmake \
    build-essential \
    autoconf \
    libtool \
    pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy Composer from official image
COPY --from=composer:2.8.9 /usr/bin/composer /usr/bin/composer

# Copy install-php-extensions from mlocati
COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

# Install PHP extensions declaratively
RUN install-php-extensions \
    mysqli \
    redis \
    pdo_mysql \
    pdo_pgsql \
    fileinfo \
    intl \
    sockets \
    bcmath \
    xsl \
    soap \
    zip \
    pcov

# Manually Build gRPC from PR #40337
# This creates a temporary directory, clones the repo, fetches the specific PR,
# builds the C++ core, then builds the PHP extension, and finally cleans up.
RUN mkdir -p /tmp/grpc-build && cd /tmp/grpc-build \
    && git clone https://github.com/grpc/grpc.git . \
    && git fetch origin pull/40337/head:pr-40337 \
    && git checkout pr-40337 \
    && git submodule update --init --recursive \
    # Build and install the gRPC C++ Core libraries first
    && mkdir -p cmake/build && cd cmake/build \
    && cmake ../.. -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF \
    && make -j$(nproc) \
    && make install \
    # Now build the PHP extension referencing the core libs
    && cd ../../src/php/ext/grpc \
    && phpize \
    && ./configure \
    && make -j$(nproc) \
    && make install \
    # Enable the extension
    && docker-php-ext-enable grpc \
    # Cleanup source files to reduce image size
    && cd / && rm -rf /tmp/grpc-build

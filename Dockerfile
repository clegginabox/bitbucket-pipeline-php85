FROM php:8.5-cli AS builder

# Install strictly what is needed to COMPILE gRPC
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    autoconf \
    libtool \
    pkg-config

# Download and Compile gRPC (PR #40337)
# We use /tmp/grpc to build
WORKDIR /tmp/grpc
RUN git clone --depth 1 https://github.com/grpc/grpc.git . \
    && git fetch origin pull/40337/head:pr-40337 \
    && git checkout pr-40337 \
    && git submodule update --init --recursive --depth 1 \
    && mkdir -p cmake/build && cd cmake/build \
    # Build the C++ Core (Static Lib)
    && cmake ../.. -DgRPC_INSTALL=ON -DgRPC_BUILD_TESTS=OFF \
    && make -j$(nproc) \
    && make install \
    # Build the PHP Extension, providing the path to the C++ core libs
    && cd ../../src/php/ext/grpc \
    && phpize \
    && ./configure --with-grpc=/usr/local \
    && make -j$(nproc) \
    && cp modules/grpc.so /tmp/grpc.so

FROM php:8.5-cli

# Standard Environment Setup
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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Composer from official image
COPY --from=composer:2.8.9 /usr/bin/composer /usr/bin/composer

# Copy install-php-extensions from mlocati
COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

# Install PHP extensions declaratively
RUN install-php-extensions mysqli \
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

# Copy grpc to a temporary spot first, then move it to the correct dir dynamically
COPY --from=builder /tmp/grpc.so /tmp/grpc.so
RUN mv /tmp/grpc.so $(php-config --extension-dir) \
    && docker-php-ext-enable grpc


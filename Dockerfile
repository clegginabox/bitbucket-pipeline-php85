FROM php:8.5-cli AS builder

# Install strictly what is needed to COMPILE gRPC
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    autoconf \
    libtool \
    pkg-config \
    re2c \
    # "linux-headers-generic" is sometimes helpful for bleeding edge builds,
    # but build-essential usually covers it.
    && apt-get clean

# Download and Compile gRPC (PR #40337)
WORKDIR /tmp/grpc
RUN git clone --depth 1 https://github.com/grpc/grpc.git . \
    && git fetch origin pull/40337/head:pr-40337 \
    && git checkout pr-40337 \
    && git submodule update --init --recursive --depth 1 \
    && mkdir -p cmake/build && cd cmake/build \
    # --- BUILD C++ CORE ---
    && cmake ../.. \
       -DCMAKE_BUILD_TYPE=Release \
       -DgRPC_INSTALL=ON \
       -DgRPC_BUILD_TESTS=OFF \
       -DgRPC_PHP_SATELLITE_SERVICES=ON \
       -DBUILD_SHARED_LIBS=ON \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    # --- BUILD PHP EXT ---
    && cd ../../src/php/ext/grpc \
    && phpize \
    # Ensure PKG_CONFIG_PATH looks in both lib and lib64 just in case
    && export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig \
    && CPPFLAGS="-I/usr/local/include" LDFLAGS="-L/usr/local/lib" ./configure --with-grpc=/usr/local \
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
    # Runtime shared libraries for gRPC might be needed here depending on linking
    # but usually the static extension approach is preferred in Docker.
    # However, since we built shared upstream, we might need libstdc++
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Composer
COPY --from=composer:2.8.9 /usr/bin/composer /usr/bin/composer

# Copy install-php-extensions
COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

# Install PHP extensions
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

# Copy grpc and enable
COPY --from=builder /tmp/grpc.so /tmp/grpc.so
RUN mv /tmp/grpc.so $(php-config --extension-dir) \
    && docker-php-ext-enable grpc


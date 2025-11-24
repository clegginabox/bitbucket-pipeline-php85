FROM clegginabox/php-grpc:8.5-cli

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

# Copy Composer
COPY --from=composer:2.8.9 /usr/bin/composer /usr/bin/composer

# Copy install-php-extensions
COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/

# Install standard extensions
RUN install-php-extensions mysqli redis pdo_mysql pdo_pgsql fileinfo intl sockets bcmath xsl soap zip pcov

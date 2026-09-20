# Stage 1: Build composer dependencies
FROM composer:2 AS vendor
WORKDIR /app
COPY . .
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --ignore-platform-reqs

# Stage 2: Build frontend assets
FROM node:20-alpine AS frontend
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY . .
COPY --from=vendor /app/vendor ./vendor
RUN npm run build

# Stage 3: PHP Application
FROM php:8.4-fpm-alpine

RUN apk add --no-cache \
    nginx \
    supervisor \
    icu-dev \
    libzip-dev \
    oniguruma-dev \
    && docker-php-ext-install \
    bcmath \
    intl \
    mbstring \
    opcache \
    pdo_mysql \
    zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy application code
COPY . .

# Copy vendor dependencies from vendor stage
COPY --from=vendor /app/vendor ./vendor

# Copy compiled assets from frontend stage
COPY --from=frontend /app/public/build ./public/build

RUN composer dump-autoload --optimize --no-dev --no-interaction

RUN mkdir -p \
    /run/nginx \
    /var/log/supervisor \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views

RUN chown -R www-data:www-data \
    storage \
    bootstrap/cache

COPY docker/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/supervisord.conf /etc/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]


# =========================
# Stage 1: Build frontend
# =========================
FROM node:22-alpine AS frontend

WORKDIR /var/www/html

COPY package*.json ./
RUN npm ci

COPY resources ./resources
COPY vite.config.js ./

RUN npm run build


# =========================
# Stage 2: Laravel
# =========================
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
    pdo_sqlite \
    zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-interaction

# Ambil hasil build Vite
COPY --from=frontend /var/www/html/public/build ./public/build

RUN mkdir -p \
    /run/nginx \
    /var/log/supervisor \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views

RUN touch database/database.sqlite

RUN chown -R www-data:www-data \
    storage \
    bootstrap/cache \
    database

COPY docker/nginx.conf /etc/nginx/http.d/default.conf
COPY docker/supervisord.conf /etc/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

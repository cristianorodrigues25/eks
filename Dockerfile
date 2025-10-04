# ===========================================
# Etapa 1: Imagem base com PHP e extensões
# ===========================================
FROM php:8.3-fpm-alpine AS base

# Instala dependências do sistema necessárias
RUN apk add --no-cache \
    curl \
    zip \
    unzip \
    git \
    oniguruma-dev \
    libxml2-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    postgresql-dev \
    nginx \
    supervisor

# Instala extensões PHP necessárias para Laravel
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    mbstring \
    xml \
    bcmath \
    gd \
    intl \
    opcache \
    pcntl

# Instala extensão do Redis
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps

# Otimizações de OPcache para produção
RUN echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=8" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.revalidate_freq=2" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.fast_shutdown=1" >> /usr/local/etc/php/conf.d/opcache.ini

# ===========================================
# Etapa 2: Dependências do Composer
# ===========================================
FROM composer:2.8 AS dependencies

WORKDIR /app

# Copia apenas os arquivos necessários para instalar dependências
COPY src/composer.json src/composer.lock ./

# Instala dependências do Composer (sem dev para produção)
RUN composer install \
    --no-interaction \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --ignore-platform-reqs

# Copia todo o código da aplicação
COPY src/ ./

# Gera o autoloader otimizado
RUN composer dump-autoload --optimize --no-dev --classmap-authoritative

# ===========================================
# Etapa 3: Build da Aplicação
# ===========================================
FROM base AS build

WORKDIR /var/www/html

# Copia o código e dependências da etapa anterior
COPY --from=dependencies /app ./

# Define permissões corretas para Laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

# Cria diretórios necessários
RUN mkdir -p storage/app/public \
    && mkdir -p storage/framework/{sessions,views,cache} \
    && mkdir -p storage/logs \
    && chown -R www-data:www-data storage \
    && chown -R www-data:www-data bootstrap/cache

# ===========================================
# Etapa 4: Produção
# ===========================================
FROM base AS production

# Cria usuário não-root para segurança
RUN addgroup -g 1000 -S laravel && \
    adduser -u 1000 -S laravel -G laravel

WORKDIR /var/www/html

# Copia aplicação da etapa de build
COPY --from=build --chown=laravel:laravel /var/www/html ./

# Configuração do Nginx
COPY --chown=laravel:laravel nginx.conf /etc/nginx/nginx.conf

# Configuração do Supervisor
COPY --chown=laravel:laravel supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Configuração do PHP-FPM
RUN sed -i 's/user = www-data/user = laravel/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/group = www-data/group = laravel/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/listen = 127.0.0.1:9000/listen = 127.0.0.1:9000/g' /usr/local/etc/php-fpm.d/www.conf

# Script de entrypoint
COPY --chown=laravel:laravel docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Cria diretórios para logs e arquivos pid
RUN mkdir -p /var/run/php /var/log/supervisor \
    && chown -R laravel:laravel /var/run/php \
    && chown -R laravel:laravel /var/log/supervisor \
    && chown -R laravel:laravel /var/lib/nginx \
    && chown -R laravel:laravel /var/log/nginx \
    && mkdir -p /var/tmp/nginx \
    && chown -R laravel:laravel /var/tmp/nginx

# Verificação de saúde
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expõe porta 8080 (Nginx)
EXPOSE 8080

# Muda para usuário não-root
USER laravel

# Define o entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Comando padrão
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
#!/bin/sh
set -e

echo "🚀 Iniciando aplicação Laravel..."

# Em Kubernetes, usamos variáveis de ambiente via secrets
# Não precisamos do arquivo .env
echo "📝 Variáveis de ambiente configuradas via Kubernetes Secrets"

# Limpa e otimiza caches
echo "🧹 Limpando e otimizando caches..."
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Em produção, faz cache das configurações
if [ "$APP_ENV" = "production" ]; then
    echo "📦 Criando cache de configuração para produção..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

# Executa migrations (apenas em desenvolvimento/staging)
if [ "$APP_ENV" != "production" ]; then
    echo "🗄️ Executando migrations do banco de dados..."
    php artisan migrate --force
fi

# Link do storage
echo "🔗 Criando link simbólico do storage..."
php artisan storage:link || true

# Ajusta permissões finais (skip em ambientes Kubernetes com volumes read-only)
echo "🔐 Configurando permissões finais..."
chmod -R 775 /var/www/html/storage 2>/dev/null || echo "⚠️ Não foi possível ajustar permissões do storage (esperado em Kubernetes)"
chmod -R 775 /var/www/html/bootstrap/cache 2>/dev/null || echo "⚠️ Não foi possível ajustar permissões do cache (esperado em Kubernetes)"

echo "✅ Aplicação Laravel pronta!"

# Executa o comando passado
exec "$@"
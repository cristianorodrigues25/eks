#!/bin/bash

# Script para criar IAM Role com OIDC para GitHub Actions
# Específico para o repositório cristianorodrigues25/eks

ROLE_NAME="github-actions-eks-deploy"
ACCOUNT_ID="120346103284"
REGION="us-east-2"
GITHUB_REPO="cristianorodrigues25/eks"
OIDC_PROVIDER="token.actions.githubusercontent.com"

echo "🔐 Criando IAM Role para GitHub Actions OIDC"
echo "📦 Repositório: $GITHUB_REPO"
echo "🏷️ Role: $ROLE_NAME"

# Verificar se os arquivos JSON existem
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f "$SCRIPT_DIR/trust-policy.json" ]; then
    echo "❌ Erro: Arquivo trust-policy.json não encontrado em $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/ecr-policy.json" ]; then
    echo "❌ Erro: Arquivo ecr-policy.json não encontrado em $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/eks-policy.json" ]; then
    echo "❌ Erro: Arquivo eks-policy.json não encontrado em $SCRIPT_DIR"
    exit 1
fi

echo "📝 Usando políticas existentes na pasta scripts/"

# Criar a Role
aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://$SCRIPT_DIR/trust-policy.json \
    --description "GitHub Actions OIDC role for EKS deployment" \
    2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Role criada com sucesso!"
else
    echo "⚠️ Role já existe ou erro ao criar. Atualizando trust policy..."
    aws iam update-assume-role-policy \
        --role-name $ROLE_NAME \
        --policy-document file://$SCRIPT_DIR/trust-policy.json
fi

# Aplicar política inline para ECR
aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name ECRAccess \
    --policy-document file://$SCRIPT_DIR/ecr-policy.json

echo "✅ Política ECR anexada!"

# Aplicar política inline para EKS
aws iam put-role-policy \
    --role-name $ROLE_NAME \
    --policy-name EKSAccess \
    --policy-document file://$SCRIPT_DIR/eks-policy.json

echo "✅ Política EKS anexada!"

# Não é necessário limpar arquivos pois estamos usando arquivos permanentes

# Obter ARN da Role
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

echo ""
echo "========================================="
echo "✅ Role configurada com sucesso!"
echo "========================================="
echo ""
echo "📋 Detalhes da Role:"
echo "   Nome: $ROLE_NAME"
echo "   ARN: $ROLE_ARN"
echo ""
echo "🔐 Permissões:"
echo "   - ECR: Push/Pull de imagens para laravel-eks-app"
echo "   - EKS: Descrever clusters e atualizar kubeconfig"
echo ""
echo "🎯 Trust Policy:"
echo "   - Provider: GitHub OIDC"
echo "   - Repositório: $GITHUB_REPO"
echo "   - Branches: Todas (*)"
echo ""
echo "📝 Para usar no GitHub Actions:"
echo "   role-to-assume: $ROLE_ARN"
echo ""
echo "⚠️ Para restringir a branches específicas, edite a trust policy:"
echo "   \"token.actions.githubusercontent.com:sub\": \"repo:${GITHUB_REPO}:ref:refs/heads/main\""
echo ""
#!/bin/bash

# Script para criar repositório ECR
# Uso: ./create-ecr-repository.sh

REPOSITORY_NAME="laravel-eks-app"
REGION="us-east-2"

echo "🔍 Verificando se o repositório ECR existe..."

# Verifica se o repositório já existe
aws ecr describe-repositories \
    --repository-names $REPOSITORY_NAME \
    --region $REGION \
    2>/dev/null

if [ $? -ne 0 ]; then
    echo "📦 Criando repositório ECR: $REPOSITORY_NAME"

    aws ecr create-repository \
        --repository-name $REPOSITORY_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256 \
        --tags Key=Project,Value=laravel-eks Key=Environment,Value=production

    if [ $? -eq 0 ]; then
        echo "✅ Repositório criado com sucesso!"

        # Obtém a URI do repositório
        REPOSITORY_URI=$(aws ecr describe-repositories \
            --repository-names $REPOSITORY_NAME \
            --region $REGION \
            --query 'repositories[0].repositoryUri' \
            --output text)

        echo "📍 URI do repositório: $REPOSITORY_URI"

        # Cria política de ciclo de vida para limpeza automática
        cat > ecr-lifecycle-policy.json << EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Manter apenas as últimas 10 imagens",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["v"],
                "countType": "imageCountMoreThan",
                "countNumber": 10
            },
            "action": {
                "type": "expire"
            }
        },
        {
            "rulePriority": 2,
            "description": "Remover imagens sem tag após 7 dias",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 7
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF

        echo "📋 Aplicando política de ciclo de vida..."
        aws ecr put-lifecycle-policy \
            --repository-name $REPOSITORY_NAME \
            --lifecycle-policy-text file://ecr-lifecycle-policy.json \
            --region $REGION

        rm ecr-lifecycle-policy.json

        echo ""
        echo "📝 Para usar no GitHub Actions com OIDC:"
        echo "   Execute: ./scripts/create-github-oidc-role.sh"
        echo "   A role será criada com permissões para ECR e EKS"
        echo ""
        echo "🚀 Para fazer push manual de uma imagem:"
        echo "   aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPOSITORY_URI"
        echo "   docker build -t $REPOSITORY_NAME ."
        echo "   docker tag $REPOSITORY_NAME:latest $REPOSITORY_URI:latest"
        echo "   docker push $REPOSITORY_URI:latest"

    else
        echo "❌ Erro ao criar o repositório"
        exit 1
    fi
else
    echo "✅ Repositório já existe!"

    REPOSITORY_URI=$(aws ecr describe-repositories \
        --repository-names $REPOSITORY_NAME \
        --region $REGION \
        --query 'repositories[0].repositoryUri' \
        --output text)

    echo "📍 URI do repositório: $REPOSITORY_URI"
fi
#!/bin/bash

# Script para criar backend do Terraform (S3 + DynamoDB)

BUCKET_NAME="terraform-state-laravel-eks"
DYNAMODB_TABLE="terraform-state-lock"
REGION="us-east-2"

echo "🔧 Configurando backend do Terraform"
echo "📦 Bucket S3: $BUCKET_NAME"
echo "🔒 DynamoDB Table: $DYNAMODB_TABLE"
echo "🌎 Região: $REGION"

# Verificar se bucket já existe
echo ""
echo "🔍 Verificando se bucket S3 já existe..."
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
    echo "✅ Bucket já existe!"
else
    echo "📦 Criando bucket S3..."
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region $REGION \
        --create-bucket-configuration LocationConstraint=$REGION

    if [ $? -eq 0 ]; then
        echo "✅ Bucket criado com sucesso!"

        # Habilitar versionamento
        echo "🔄 Habilitando versionamento..."
        aws s3api put-bucket-versioning \
            --bucket $BUCKET_NAME \
            --versioning-configuration Status=Enabled

        # Habilitar criptografia
        echo "🔐 Habilitando criptografia..."
        aws s3api put-bucket-encryption \
            --bucket $BUCKET_NAME \
            --server-side-encryption-configuration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }]
            }'

        # Bloquear acesso público
        echo "🚫 Bloqueando acesso público..."
        aws s3api put-public-access-block \
            --bucket $BUCKET_NAME \
            --public-access-block-configuration \
                "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    else
        echo "❌ Erro ao criar bucket"
        exit 1
    fi
fi

# Verificar se tabela DynamoDB já existe
echo ""
echo "🔍 Verificando se tabela DynamoDB já existe..."
if aws dynamodb describe-table --table-name $DYNAMODB_TABLE --region $REGION 2>/dev/null; then
    echo "✅ Tabela DynamoDB já existe!"
else
    echo "🗄️ Criando tabela DynamoDB..."
    aws dynamodb create-table \
        --table-name $DYNAMODB_TABLE \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region $REGION \
        --tags Key=Project,Value=laravel-eks Key=ManagedBy,Value=terraform

    if [ $? -eq 0 ]; then
        echo "✅ Tabela DynamoDB criada com sucesso!"

        # Aguardar tabela ficar ativa
        echo "⏳ Aguardando tabela ficar ativa..."
        aws dynamodb wait table-exists \
            --table-name $DYNAMODB_TABLE \
            --region $REGION
        echo "✅ Tabela ativa!"
    else
        echo "❌ Erro ao criar tabela DynamoDB"
        exit 1
    fi
fi

echo ""
echo "========================================="
echo "✅ Backend do Terraform configurado!"
echo "========================================="
echo ""
echo "📝 Configuração do backend no main.tf:"
echo ""
echo "backend \"s3\" {"
echo "  bucket         = \"$BUCKET_NAME\""
echo "  key            = \"eks/terraform.tfstate\""
echo "  region         = \"$REGION\""
echo "  dynamodb_table = \"$DYNAMODB_TABLE\""
echo "  encrypt        = true"
echo "}"
echo ""
echo "🚀 Próximos passos:"
echo "   cd infrastructure/terraform"
echo "   terraform init"
echo "   terraform plan"
echo "   terraform apply"
echo ""

#!/bin/bash

# Script para instalar ou atualizar o syn-guard

set -e

# --- Variáveis ---
GITHUB_REPO="nettaskjr/syn-guard"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="syn-guard"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Iniciando a instalação do $SCRIPT_NAME...${NC}"

# --- Verificações ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Este script precisa ser executado com privilégios de superusuário (sudo).${NC}"
  echo "Por favor, execute novamente com: sudo bash $0"
  exit 1
fi

if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Dependências 'curl' e 'jq' são necessárias.${NC}"
    echo "Instalando dependências..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y curl jq
    elif command -v dnf &> /dev/null; then
        dnf install -y curl jq
    elif command -v pacman &> /dev/null; then
        pacman -Syu --noconfirm curl jq
    else
        echo "Não foi possível determinar o gerenciador de pacotes. Por favor, instale 'curl' e 'jq' manualmente."
        exit 1
    fi
fi

# --- Instalação ---
echo "Buscando a versão mais recente..."

# Obtém a URL do asset da última release que contém 'syn-guard.sh'
LATEST_RELEASE_URL=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | jq -r '.assets[] | select(.name | contains("syn-guard.sh")) | .browser_download_url' | head -n 1)

if [ -z "$LATEST_RELEASE_URL" ]; then
    echo "Não foi possível encontrar um asset de release contendo 'syn-guard.sh'. Verifique o repositório e as releases."
    exit 1
fi

echo "Baixando a versão mais recente de $LATEST_RELEASE_URL..."
curl -sL "$LATEST_RELEASE_URL" -o "${INSTALL_DIR}/${SCRIPT_NAME}"

echo "Instalando em ${INSTALL_DIR}/${SCRIPT_NAME}..."
chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}"

echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
echo "Execute '$SCRIPT_NAME' para começar."
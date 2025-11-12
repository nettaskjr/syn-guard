#!/bin/bash

# Script para instalar ou atualizar o syn-guard

set -e

# --- Variáveis ---
GITHUB_REPO="nettaskjr/syn-guard"
INSTALL_DIR="/usr/bin"
SCRIPT_NAME="syn-guard"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem Cor

echo -e "${BLUE}Iniciando a instalação do $SCRIPT_NAME...${NC}"

# --- Verificações ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Este script precisa ser executado com privilégios de superusuário (sudo).${NC}"
    echo -e "${YELLOW}Por favor, execute novamente com: sudo bash $0${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Dependências 'curl' e 'jq' são necessárias.${NC}"
    echo -e "${BLUE}Instalando dependências..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y curl jq
    elif command -v dnf &> /dev/null; then
        dnf install -y curl jq
    elif command -v pacman &> /dev/null; then
        pacman -Syu --noconfirm curl jq
    else
        echo -e "${RED}Não foi possível determinar o gerenciador de pacotes. Por favor, instale 'curl' e 'jq' manualmente.${NC}"
        exit 1
    fi
fi

# --- Instalação ---
echo -e "${BLUE}Buscando a versão mais recente...${NC}"

# Obtém a URL do asset da última release que contém 'syn-guard.sh'
TAG_NAME=$(curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest | jq -r '.tag_name')
LATEST_RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG_NAME}/${SCRIPT_NAME}-${TAG_NAME}.tar.gz"

if [ -z "$LATEST_RELEASE_URL" ]; then
    echo -e "${RED}Não foi possível encontrar um asset de release contendo 'syn-guard.sh'. Verifique o repositório e as releases.${NC}"
    exit 1
fi

# Baixa o arquivo tar.gz e extrai para o diretório de instalação
echo -e "${BLUE}Baixando e extraindo ${LATEST_RELEASE_URL}...${NC}"
curl -L "${LATEST_RELEASE_URL}"| tar -xz -C "${INSTALL_DIR}"

# Concede permissão de execução e retira extensão .sh
chmod +x "${INSTALL_DIR}/${SCRIPT_NAME}.sh" && mv "${INSTALL_DIR}/${SCRIPT_NAME}.sh" "${INSTALL_DIR}/${SCRIPT_NAME}"

echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
echo -e "${BLUE}Execute '$SCRIPT_NAME' para começar.${NC}"
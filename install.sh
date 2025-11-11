#!/bin/bash

# Script para instalar ou atualizar o syn-guard

set -e

# --- Variáveis ---
GITHUB_REPO="nettaskjr/syn-guard"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="syn-guard"
SCRIPT_FOLDER="${INSTALL_DIR}/${SCRIPT_NAME}"

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
    echo "${YELLOW}Por favor, execute novamente com: sudo bash $0${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Dependências 'curl' e 'jq' são necessárias.${NC}"
    echo "${BLUE}Instalando dependências..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y curl jq
    elif command -v dnf &> /dev/null; then
        dnf install -y curl jq
    elif command -v pacman &> /dev/null; then
        pacman -Syu --noconfirm curl jq
    else
        echo "${RED}Não foi possível determinar o gerenciador de pacotes. Por favor, instale 'curl' e 'jq' manualmente.${NC}"
        exit 1
    fi
fi

# --- Instalação ---
echo "${BLUE}Buscando a versão mais recente...${NC}"

# Obtém a URL do asset da última release que contém 'syn-guard.sh'
TAG_NAME=$(curl -s https://api.github.com/repos/${GITHUB_REPO}/releases/latest | jq -r '.tag_name')
LATEST_RELEASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG_NAME}/${SCRIPT_NAME}_${TAG_NAME}.tar.gz"

if [ -z "$LATEST_RELEASE_URL" ]; then
    echo "${RED}Não foi possível encontrar um asset de release contendo 'syn-guard.sh'. Verifique o repositório e as releases.${NC}"
    exit 1
fi

# Cria o diretório de instalação se não existir
echo "${BLUE}Criando diretório de instalação em ${SCRIPT_FOLDER}...${NC}"
[ -f "${SCRIPT_FOLDER}" ] || rm -Rf "${SCRIPT_FOLDER}"
mkdir -p "${SCRIPT_FOLDER}"

# Baixa o arquivo tar.gz e extrai para o diretório de instalação
echo "${BLUE}Baixando e extraindo ${LATEST_RELEASE_URL}...${NC}"
curl -L "${LATEST_RELEASE_URL}"| tar -xz -C "${SCRIPT_FOLDER}"

# Concede permissão de execução
chmod +x "${SCRIPT_FOLDER}/${SCRIPT_NAME}.sh"

echo -e "${GREEN}Instalação concluída com sucesso!${NC}"
echo "Execute '$SCRIPT_NAME' para começar."
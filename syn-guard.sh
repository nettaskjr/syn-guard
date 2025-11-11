#!/bin/bash

# syn-guard: Um script de backup simples baseado em rsync.

# Encerra imediatamente se um comando sair com um status diferente de zero.
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem Cor

# --- Configuração ---
CONFIG_FILE="$HOME/.syn-guard.json"
MOUNT_POINT="/mnt"
LOG_DIR="/var/log/syn-guard"
LOG_FILE="$LOG_DIR/syn-guard_$(date +%Y-%m-%d).log"

# --- Funções Auxiliares ---

# Registra mensagens
log() {
    local level="$1"
    shift
    local message="$*"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [$level] - $message" | sudo tee -a "$LOG_FILE" >/dev/null
}

info() {
    echo -e "${BLUE}[INFO] $1 ${NC}"
    log "INFO" "$1"
}

success() {
    echo -e "${GREEN}[SUCCESS] $1 ${NC}"
    log "SUCCESS" "$1"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1 ${NC}"
    log "WARNING" "$1"
}

error() {
    echo -e "${RED}[ERROR] $1 ${NC}" >&2
    log "ERROR" "$1"
}

# Verifica as dependências necessárias
check_dependencies() {
    local missing_deps=()
    for cmd in rsync lsblk jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Dependências faltando: ${missing_deps[*]}. Por favor, instale-as e tente novamente."
        exit 1
    fi
}

# Cria os diretórios e arquivos necessários
setup_environment() {
    if [ ! -d "$MOUNT_POINT" ]; then
        info "Ponto de montagem $MOUNT_POINT não encontrado. Criando..."
        sudo mkdir -p "$MOUNT_POINT"
        success "Ponto de montagem criado."
    fi

    if [ ! -d "$LOG_DIR" ]; then
        info "Diretório de log $LOG_DIR não encontrado. Criando..."
        sudo mkdir -p "$LOG_DIR"
        sudo chown "$USER":"$USER" "$LOG_DIR"
        success "Diretório de log criado."
    fi
    sudo touch "$LOG_FILE"
    sudo chown "$USER":"$USER" "$LOG_FILE"
}

# Lê a configuração do arquivo JSON
read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        SOURCE_DIR=$(jq -r '.source_dir' "$CONFIG_FILE")
        DEST_UUID=$(jq -r '.dest_uuid' "$CONFIG_FILE")
        EXCLUDE_DIRS_JSON=$(jq -c '.exclude_dirs' "$CONFIG_FILE")
    else
        SOURCE_DIR=""
        DEST_UUID=""
    fi
}

# Escreve a configuração no arquivo JSON
write_config() {
    local source_dir="$1"
    local dest_uuid="$2"
    
    # Cria um array JSON de exclusões padrão
    local excludes_json
    excludes_json=$(jq -n '[
        ".cache/", ".config/Insync/", ".local/share/Insync/", ".local/share/Trash/", 
        ".var/app/com.valvesoftware.Steam/Insync/", "s3/", "VirtualBox VMs/", 
        "Insync/", "AppImages/", "Projetos-github/", "/timeshift/"
    ]')

    local howto_exclude="HOW-TO: Para personalizar as exclusões, edite o array 'exclude_dirs' abaixo. Os caminhos são relativos à pasta de origem. Adicione uma '/' no final para excluir o conteúdo de um diretório. Ex: 'minha_pasta/'."

    jq -n --arg source_dir "$source_dir" --arg dest_uuid "$dest_uuid" --arg howto "$howto_exclude" --argjson excludes "$excludes_json" \
        '{source_dir: $source_dir, dest_uuid: $dest_uuid, _howto_exclude: $howto, exclude_dirs: $excludes}' > "$CONFIG_FILE"

    chmod 600 "$CONFIG_FILE" # Define permissões restritivas
    success "Configuração salva em $CONFIG_FILE"
}

# Assistente de configuração inicial
setup_wizard() {
    local source_dir
    while true; do
        read -erp "Por favor, informe o caminho completo da pasta de origem para o backup: " -i "/home/$USER/" source_dir
        if [ -d "$source_dir" ]; then
            break
        else
            error "O diretório '$source_dir' não existe. Tente novamente."
        fi
    done

    local device_map=()
    
    info "Detectando dispositivos de armazenamento..."
    # Lê a saída do lsblk diretamente para o array 'device_map', corrigindo o aviso SC2124 do shellcheck.
    mapfile -t device_map < <(lsblk -o NAME,LABEL,SIZE,FSTYPE,UUID,MOUNTPOINT -p -n -l | grep -v -E 'swap|ntfs|rom' | awk '$5!=""')

    if [ ${#device_map[@]} -eq 0 ]; then
        error "Nenhum dispositivo de armazenamento adequado encontrado. O script não pode continuar."
        exit 1
    fi

    local selected_device_info
    local dest_uuid
    while true; do
        info "Por favor, selecione a unidade de destino para o backup:"
        for i in "${!device_map[@]}"; do
            printf "%d) %s\n" "$((i+1))" "${device_map[$i]}"
        done

        read -rp "Digite o número do dispositivo: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#device_map[@]}" ]; then
            selected_device_info="${device_map[$((choice-1))]}"
            # Extrai o UUID (quinta coluna)
            dest_uuid=$(echo "$selected_device_info" | awk '{print $5}')
            
            if [ -z "$dest_uuid" ]; then
                error "O dispositivo selecionado não possui um UUID. Por favor, escolha outro."
                continue
            fi

            info "Você selecionou: $selected_device_info"
            read -rp "Confirma a seleção? (s/n/c): " confirm
            case "$confirm" in
                [sS]) 
                    write_config "$source_dir" "$dest_uuid"
                    success "Configuração inicial concluída."
                    return 0
                    ;;
                [nN]) 
                    continue 
                    ;;
                [cC]) 
                    warning "Configuração cancelada. Saindo."
                    exit 0
                    ;;
                *) 
                    warning "Opção inválida. Por favor, digite 's' para sim, 'n' para não ou 'c' para cancelar."
                    ;;
            esac
        else
            error "Seleção inválida. Tente novamente."
        fi
    done
}


# Executa o processo de restauração
run_restore() {
    log "INFO" "Iniciando processo de restauração..."

    # Encontra o caminho do dispositivo a partir do UUID
    local dest_device
    dest_device=$(findfs "UUID=$DEST_UUID")

    if [ -z "$dest_device" ]; then
        error "Dispositivo de backup com UUID $DEST_UUID não encontrado. Conecte o dispositivo e tente novamente."
        exit 1
    fi

    log "INFO" "Dispositivo de backup encontrado: $dest_device"

    # Verifica e lida com a montagem
    local current_mount_point
    current_mount_point=$(lsblk -no MOUNTPOINT "$dest_device")
    local mounted_by_script=false

    if [ -n "$current_mount_point" ]; then
        log "INFO" "Dispositivo já está montado em '$current_mount_point'."
        if [ "$current_mount_point" != "$MOUNT_POINT" ]; then
            log "INFO" "Desmontando de '$current_mount_point' para montar no local padrão."
            info "Dispositivo será remontado em $MOUNT_POINT."
            sudo umount "$current_mount_point"
            log "INFO" "Dispositivo desmontado."
            current_mount_point="" # Marca como desmontado para acionar a remontagem
        fi
    fi

    if [ -z "$current_mount_point" ]; then
        log "INFO" "Montando dispositivo $dest_device em $MOUNT_POINT..."
        info "Montando dispositivo de backup..."
        sudo mount "$dest_device" "$MOUNT_POINT"
        sudo chown "$USER":"$USER" "$MOUNT_POINT"
        log "INFO" "Dispositivo montado com sucesso."
        mounted_by_script=true
    fi

    local backup_path="$MOUNT_POINT/syn-guard-backup/"

    if [ ! -d "$backup_path" ]; then
        error "Diretório de backup '$backup_path' não encontrado no dispositivo de destino."
        if [ "$mounted_by_script" = true ]; then
            sudo umount "$MOUNT_POINT"
        fi
        exit 1
    fi

    local restore_dir
    while true; do
        read -erp "Informe o caminho completo da pasta para onde deseja restaurar o backup: " -i "$HOME/restore_syn-guard_$(date +%Y-%m-%d)/" restore_dir
        
        # Pergunta se deve criar o diretório
        if [ ! -d "$restore_dir" ]; then
            read -rp "O diretório '$restore_dir' não existe. Deseja criá-lo? (s/n): " create_dir_choice
            if [[ "$create_dir_choice" =~ ^[sS]$ ]]; then
                mkdir -p "$restore_dir"
                info "Diretório '$restore_dir' criado."
                break
            else
                warning "Criação do diretório cancelada. Por favor, informe um novo caminho."
                continue # Volta para o início do loop para pedir o caminho novamente
            fi
        else
            # Se o diretório já existe, confirma se o usuário quer restaurar para lá
            read -rp "O diretório '$restore_dir' já existe. Deseja restaurar os arquivos para dentro dele? (s/n): " confirm_restore
            if [[ "$confirm_restore" =~ ^[sS]$ ]]; then
                break
            else
                info "Restauração para '$restore_dir' cancelada. Informe um novo caminho."
            fi
        fi
    done

    info "Iniciando restauração de '$backup_path' para '$restore_dir'..."
    sudo rsync -av --progress "$backup_path" "$restore_dir" 2>&1 | tee -a "$LOG_FILE"

    if [ "$mounted_by_script" = true ]; then
        log "INFO" "Desmontando o dispositivo $dest_device de $MOUNT_POINT."
        sudo umount "$MOUNT_POINT"
        log "INFO" "Dispositivo desmontado com sucesso."
    fi

    success "Restauração concluída com sucesso para o diretório '$restore_dir'."
}

# Executa o processo de backup
run_backup() {
    log "INFO" "Iniciando processo de backup..."

    # Valida o diretório de origem
    if [ ! -d "$SOURCE_DIR" ]; then
        error "Diretório de origem '$SOURCE_DIR' não encontrado. Verifique o arquivo de configuração."
        exit 1
    fi

    log "INFO" "Diretório de origem: $SOURCE_DIR"

    # Encontra o caminho do dispositivo a partir do UUID
    local dest_device
    dest_device=$(findfs "UUID=$DEST_UUID")

    if [ -z "$dest_device" ]; then
        error "Dispositivo de destino com UUID $DEST_UUID não encontrado. Conecte o dispositivo e tente novamente."
        exit 1
    fi

    log "INFO" "Dispositivo de destino encontrado: $dest_device"

    # Verifica e lida com a montagem
    # Nós garantiremos que o dispositivo esteja sempre montado em nosso MOUNT_POINT padrão
    local current_mount_point
    current_mount_point=$(lsblk -no MOUNTPOINT "$dest_device")
    local mounted_by_script=false

    if [ -n "$current_mount_point" ]; then
        log "INFO" "Dispositivo já está montado em '$current_mount_point'."
        if [ "$current_mount_point" != "$MOUNT_POINT" ]; then
            log "INFO" "Desmontando de '$current_mount_point' para montar no local padrão."
            info "Dispositivo será remontado em $MOUNT_POINT."
            sudo umount "$current_mount_point"
            log "INFO" "Dispositivo desmontado."
            current_mount_point="" # Marca como desmontado para acionar a remontagem
        fi
    fi

    if [ -z "$current_mount_point" ]; then
        log "INFO" "Montando dispositivo $dest_device em $MOUNT_POINT..."
        info "Montando dispositivo de backup..."
        sudo mount "$dest_device" "$MOUNT_POINT"
        sudo chown "$USER":"$USER" "$MOUNT_POINT"
        log "INFO" "Dispositivo montado com sucesso."
        mounted_by_script=true
    fi

    DEST_BACKUP_PATH="$MOUNT_POINT/syn-guard-backup"
    
    # Agora que as permissões estão corretas, cria o diretório de backup
    # Cria o diretório de destino do backup se ele não existir
    if [ ! -d "$DEST_BACKUP_PATH" ]; then
        log "INFO" "Criando diretório de backup em $DEST_BACKUP_PATH"
        mkdir -p "$DEST_BACKUP_PATH"
    fi

    # Verifica o espaço em disco disponível (ex: pelo menos 1GB livre)
    local available_space
    available_space=$(df -BG "$DEST_BACKUP_PATH" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt 1 ]; then
        warning "Pouco espaço em disco no dispositivo de destino (Menos de 1GB disponível). O backup pode falhar."
    fi

    log "INFO" "Iniciando sincronização com rsync..."
    info "Executando o backup... Isso pode levar algum tempo."

    # Constrói as opções de exclusão do rsync a partir do array JSON
    local rsync_excludes=()
    if [[ -n "$EXCLUDE_DIRS_JSON" && "$EXCLUDE_DIRS_JSON" != "null" ]]; then
        mapfile -t exclude_paths < <(echo "$EXCLUDE_DIRS_JSON" | jq -r '.[]')
        for path in "${exclude_paths[@]}"; do
            rsync_excludes+=(--exclude="$path")
        done
    fi

    # Executa o rsync
    sudo rsync -av --delete --progress "${rsync_excludes[@]}" "$SOURCE_DIR/" "$DEST_BACKUP_PATH/" 2>&1 | tee -a "$LOG_FILE"

    log "INFO" "Sincronização com rsync concluída."

    # Desmonta o dispositivo se nós o montamos
    if [ "$mounted_by_script" = true ]; then
        log "INFO" "Desmontando o dispositivo $dest_device de $MOUNT_POINT."
        sudo umount "$MOUNT_POINT"
        log "INFO" "Dispositivo desmontado com sucesso."
    fi

    success "Backup concluído com sucesso."
}


# --- Lógica Principal ---

main() {
    check_dependencies
    setup_environment

    # Verifica se o arquivo de configuração existe
    if [ ! -f "$CONFIG_FILE" ]; then
        warning "Arquivo de configuração não encontrado. Iniciando configuração inicial..."
        setup_wizard
        read_config # Lê a configuração recém-criada
    else
        info "Arquivo de configuração encontrado. Lendo configurações..."
        read_config
    fi

    # Menu de Ação
    info "O que você gostaria de fazer?"
    select action in "Fazer Backup" "Restaurar Backup" "Sair"; do
        case $action in
            "Fazer Backup")
                run_backup
                break
                ;;
            "Restaurar Backup")
                run_restore
                break
                ;;
            "Sair")
                info "Operação cancelada pelo usuário."
                exit 0
                ;;
            *) 
                warning "Opção inválida. Por favor, selecione 1, 2 ou 3."
                ;;
        esac
    done

    log "INFO" "Script finalizado."
}

# --- Ponto de Entrada do Script ---
main "$@"
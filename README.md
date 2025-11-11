# syn-guard

`syn-guard` é um script de backup em BASH que utiliza o `rsync` para sincronizar pastas de forma segura e eficiente.

## Funcionalidades

- Backup incremental de pastas.
- Configuração inicial para definir a pasta de origem e a unidade de destino.
- Validação da unidade de destino através do UUID.
- Montagem automática da unidade de destino, se necessário.
- Logs detalhados de cada operação de backup.

## Requisitos

- `bash`
- `rsync`
- `lsblk`
- `jq`

A maioria das distribuições Linux já vem com `bash`, `rsync` e `lsblk`. Você pode precisar instalar o `jq`.

**Debian/Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install jq
```

**Fedora/CentOS/RHEL:**
```bash
sudo dnf install jq
```

**Arch Linux:**
```bash
sudo pacman -S jq
```

## Instalação

1. Clone este repositório ou baixe o script `syn-guard.sh`.
2. Dê permissão de execução ao script:
   ```bash
   chmod +x syn-guard.sh
   ```

## Uso

Execute o script no seu terminal:

```bash
./syn-guard.sh
```

### Primeira Execução

Na primeira vez que você executar o `syn-guard`, ele iniciará um assistente de configuração para solicitar:

1.  **A pasta de origem:** O caminho absoluto da pasta que você deseja fazer backup.
2.  **A unidade de destino:** Você verá uma lista de unidades de armazenamento disponíveis. Basta selecionar o número correspondente à unidade que você deseja usar para o backup.

As configurações são salvas em `~/.syn-guard.json`.

### Personalizando Pastas de Exclusão

Você pode personalizar quais pastas e arquivos serão ignorados durante o backup editando diretamente o arquivo de configuração `~/.syn-guard.json`.

1.  Abra o arquivo `~/.syn-guard.json` em um editor de texto.
2.  Localize o array `exclude_dirs`.
3.  Adicione ou remova os caminhos que deseja excluir.

Os caminhos são relativos à pasta de origem do backup. Certifique-se de adicionar uma barra (`/`) no final do nome de um diretório para excluir seu conteúdo.

O próprio arquivo contém uma chave `_howto_exclude` com instruções para facilitar a edição.


### Execuções Subsequentes

Após a configuração inicial, o script irá ler as configurações salvas, montar a unidade de destino (se necessário) e executar o backup incremental usando `rsync`.

## Arquivos de Log

Os logs de todas as operações de backup são armazenados em `/var/log/syn-guard/`. Um novo arquivo de log é criado para cada dia no formato `syn-guard_YYYY-MM-DD.log`.

## Como Contribuir

Contribuições são bem-vindas! Sinta-se à vontade para abrir uma issue ou enviar um pull request.

## Licença

Este projeto é de código aberto.
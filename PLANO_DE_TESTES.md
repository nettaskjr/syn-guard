# Plano de Testes para o syn-guard

Este documento descreve o plano de testes para o script `syn-guard.sh`, garantindo que todas as funcionalidades, incluindo backup e restauração, operem conforme o esperado.

## 1. Objetivo

Validar a funcionalidade, a confiabilidade e a robustez do script `syn-guard.sh` em diferentes cenários, incluindo a primeira configuração, execuções de backup, execuções de restauração, tratamento de erros e casos extremos.

## 2. Pré-requisitos do Ambiente de Teste

- **Hardware**:
  - Pelo menos um disco rígido ou partição interna.
  - Pelo menos um dispositivo de armazenamento externo (pen drive, HD externo) formatado com um sistema de arquivos Linux (ex: `ext4`).
- **Software**:
  - Uma distribuição Linux.
  - As dependências `rsync`, `lsblk`, e `jq` instaladas.
- **Setup**:
  - Uma pasta de origem para teste com alguns arquivos e subpastas. Ex: `~/teste_backup_origem`.
  - O script `syn-guard.sh` com permissão de execução (`chmod +x syn-guard.sh`).

---

## 3. Casos de Teste

A tabela a seguir detalha os casos de teste a serem executados.

| Cenário | ID do Teste | Descrição | Passos para Execução | Resultado Esperado |
| :--- | :--- | :--- | :--- | :--- |
| **1. Primeira Execução e Configuração** | 1.1 | Execução do script pela primeira vez | 1. Remover `~/.syn-guard.json` se existir.<br>2. Executar `./syn-guard.sh`.<br>3. Seguir o assistente, informando uma pasta de origem válida e selecionando um dispositivo de destino. | O script deve guiar o usuário pelo assistente de configuração e criar o arquivo `~/.syn-guard.json` com os dados corretos. |
| | 1.2 | Cancelar a configuração inicial | 1. Executar o assistente de configuração.<br>2. Digitar 'c' quando a confirmação do dispositivo for solicitada. | O script deve exibir a mensagem "Configuração cancelada. Saindo." e encerrar a execução. |
| | 1.3 | Informar um diretório de origem inválido | 1. Executar o assistente de configuração.<br>2. Informar um caminho para uma pasta que não existe. | O script deve exibir uma mensagem de erro e solicitar o caminho novamente. |
| | 1.4 | Verificar permissões do arquivo de configuração | 1. Concluir o `setup_wizard`.<br>2. Executar `ls -l ~/.syn-guard.json`. | As permissões do arquivo devem ser `-rw-------` (600), garantindo que apenas o proprietário possa ler e escrever. |
| **2. Execução de Backup** | 2.1 | Execução de um backup bem-sucedido | 1. Com a configuração já feita, executar o script.<br>2. Selecionar "Fazer Backup".<br>3. Conectar o dispositivo de destino. | O script deve montar o dispositivo, sincronizar os arquivos da origem para o destino e desmontar o dispositivo. Uma mensagem de sucesso deve ser exibida. |
| | 2.2 | Execução de um backup incremental | 1. Após um primeiro backup, adicionar/modificar/remover arquivos na pasta de origem.<br>2. Executar o backup novamente. | O `rsync` deve sincronizar apenas os arquivos alterados. Arquivos removidos na origem devem ser removidos no backup (`--delete`). |
| | 2.3 | Backup com dispositivo de destino desconectado | 1. Garantir que o dispositivo de destino (UUID configurado) não esteja conectado.<br>2. Executar o backup. | O script deve exibir uma mensagem de erro informando que o dispositivo com o UUID especificado não foi encontrado e encerrar. |
| | 2.4 | Backup com diretório de origem ausente | 1. Renomear ou remover o diretório de origem configurado.<br>2. Executar o backup. | O script deve exibir uma mensagem de erro informando que o diretório de origem não foi encontrado e encerrar. |
| | 2.5 | Verificar a exclusão de pastas (`exclude_dirs`) | 1. Editar `~/.syn-guard.json` e adicionar uma pasta de teste ao array `exclude_dirs`.<br>2. Executar o backup. | A pasta especificada em `exclude_dirs` não deve ser copiada para o diretório de backup no dispositivo de destino. |
| **3. Execução de Restauração** | 3.1 | Restauração para um novo diretório | 1. Executar o script e selecionar "Restaurar Backup".<br>2. Informar um caminho para um diretório que não existe.<br>3. Confirmar a criação do diretório. | O script deve criar o diretório de destino e restaurar o conteúdo do backup para dentro dele. |
| | 3.2 | Restauração para um diretório existente | 1. Executar a restauração.<br>2. Informar o caminho para um diretório que já existe.<br>3. Confirmar a restauração para o local. | O script deve copiar os arquivos de backup para o diretório existente, mesclando o conteúdo. |
| | 3.3 | Tentar restaurar com dispositivo de backup desconectado | 1. Garantir que o dispositivo de destino não esteja conectado.<br>2. Executar a restauração. | O script deve exibir uma mensagem de erro informando que o dispositivo não foi encontrado e encerrar. |
| | 3.4 | Cancelar a criação do diretório de restauração | 1. Executar a restauração.<br>2. Informar um caminho para um diretório que não existe.<br>3. Digitar 'n' quando perguntado se deseja criar o diretório. | O script deve cancelar a operação e solicitar um novo caminho. |
| **4. Tratamento de Erros e Validações** | 4.1 | Execução sem dependências | 1. Desinstalar uma das dependências (ex: `jq`).<br>2. Executar o script. | O script deve detectar a dependência ausente, exibir uma mensagem de erro clara e encerrar a execução. |
| | 4.2 | Pouco espaço em disco no destino | 1. Preencher o dispositivo de destino até que reste menos de 1GB de espaço livre.<br>2. Executar o backup. | O script deve exibir um aviso "Pouco espaço em disco no dispositivo de destino". O backup tentará prosseguir. |

---

## 4. Estrutura de Pastas e Arquivos para Teste

Para facilitar os testes, a seguinte estrutura pode ser criada na pasta de origem:

```
~/teste_backup_origem/
├── documentos/
│   ├── relatorio_final.docx
│   └── apresentacao.pptx
├── imagens/
│   ├── ferias_2024/
│   │   ├── foto1.jpg
│   │   └── foto2.jpg
│   └── logo.png
├── videos/
│   └── tutorial.mp4
├── .cache/
│   └── temp_file.tmp
└── arquivo_raiz.txt
```

Ao configurar as exclusões, a pasta `.cache/` deve ser adicionada para validar o Teste 2.5.

#!/bin/bash

# Importando os módulos de autenticação
# O caminho é relativo à pasta onde você executa o script
source "./auth/cpf.sh"
source "./auth/login.sh"

# Loop do Terminal Interativo (REPL / Menu)
clear
echo "=================================="
echo "   Bem-vindo ao Sistema CLI!"
echo "=================================="

while true; do
    echo ""
    echo "Comandos disponíveis:"
    echo "  login  - Fazer login com CPF"
    echo "  sair   - Fechar o sistema"
    echo -n "sistema> "
    
    # Lê o comando digitado pelo usuário
    read -r comando
    
    case "$comando" in
        login)
            fazer_login
            ;;
        sair | exit)
            echo "Encerrando o sistema. Até logo!"
            break
            ;;
        *)
            echo "Comando desconhecido: '$comando'. Digite 'login' ou 'sair'."
            ;; 
    esac
done

#!/bin/bash

fazer_login() {
    echo "--- TELA DE LOGIN ---"
    read -p "Digite seu CPF (com ou sem pontos): " cpf_input
    
    if validar_cpf "$cpf_input"; then
        echo "✅ Sucesso: CPF válido! Acesso concedido."
    else
        echo "❌ Erro: CPF inválido. Acesso negado."
    fi
}

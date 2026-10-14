#!/bin/bash

validar_cpf() {
    local cpf="$1"
    cpf=$(echo "$cpf" | tr -cd '[:digit:]')
    
    if [ ${#cpf} -eq 11 ] && ! [[ "$cpf" =~ ^([0-9])\1{10}$ ]]; then
        return 0 # Sucesso (válido)
    else
        return 1 # Erro (inválido)
    fi
}

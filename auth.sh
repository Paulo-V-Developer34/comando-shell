#!/usr/bin/env bash
# auth.sh - gerenciamento de usuários e grupos
#
# Biblioteca para ser carregada com `source` (usada por main.sh e project.sh).
# Requer root, pois usa useradd, usermod, gpasswd, userdel e chpasswd.

GRUPO_ADMIN="admin"
GRUPOS_VALIDOS=(admin bancodedados frontend backend)

# Usuário que está operando o sistema (definido pelo login em main.sh).
USUARIO_ATUAL="${USUARIO_ATUAL:-}"
# Modo bootstrap: usado só enquanto não existe nenhum admin no sistema.
MODO_BOOTSTRAP="${MODO_BOOTSTRAP:-0}"

# ---------------------------------------------------------------- utilidades

msg_erro() { echo "erro: $*" >&2; }
msg_ok()   { echo "ok: $*"; }

grupo_valido() {
  local g
  for g in "${GRUPOS_VALIDOS[@]}"; do
    [[ "$1" == "$g" ]] && return 0
  done
  return 1
}

usuario_existe() { id "$1" &>/dev/null; }

usuario_no_grupo() {
  id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx -- "$2"
}

usuario_valido() { [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; }

# Garante que os 4 grupos existam no sistema.
garantir_grupos() {
  local g
  for g in "${GRUPOS_VALIDOS[@]}"; do
    getent group "$g" &>/dev/null || groupadd "$g" || return 1
  done
}

contar_admins() {
  getent group "$GRUPO_ADMIN" | cut -d: -f4 | tr ',' '\n' | grep -c .
}

# Permite a ação se for admin (ou se estiver no modo bootstrap).
exigir_admin() {
  [[ "$MODO_BOOTSTRAP" == "1" ]] && return 0
  if [[ -n "$USUARIO_ATUAL" ]] && usuario_no_grupo "$USUARIO_ATUAL" "$GRUPO_ADMIN"; then
    return 0
  fi
  msg_erro "esta ação exige que o usuário pertença ao grupo '$GRUPO_ADMIN'."
  return 1
}

# ---------------------------------------------------------------------- CPF

cpf_normalizar() { echo "${1//[^0-9]/}"; }

# Valida CPF (11 dígitos, não repetidos, dígitos verificadores corretos).
cpf_valido() {
  local cpf soma resto d1 d2 i
  cpf="$(cpf_normalizar "$1")"

  [[ ${#cpf} -eq 11 ]] || return 1
  # todos os dígitos iguais (000.000.000-00, 111.111.111-11, ...) são inválidos
  [[ -z "${cpf//${cpf:0:1}/}" ]] && return 1

  soma=0
  for ((i = 0; i < 9; i++)); do soma=$((soma + ${cpf:i:1} * (10 - i))); done
  resto=$(((soma * 10) % 11)); ((resto == 10)) && resto=0
  d1=$resto
  ((d1 == ${cpf:9:1})) || return 1

  soma=0
  for ((i = 0; i < 10; i++)); do soma=$((soma + ${cpf:i:1} * (11 - i))); done
  resto=$(((soma * 10) % 11)); ((resto == 10)) && resto=0
  d2=$resto
  ((d2 == ${cpf:10:1})) || return 1

  return 0
}

# ------------------------------------------------------------ autenticação

# Confere usuário e senha (CPF) contra /etc/shadow.
# Funciona com hashes SHA-512 ($6$), que é o que criar_usuario grava.
autenticar() {
  local usuario="$1" senha hash prefixo calculado
  senha="$(cpf_normalizar "$2")"

  hash="$(awk -F: -v u="$usuario" '$1==u {print $2}' /etc/shadow 2>/dev/null)"
  [[ "$hash" == '$6$'* ]] || return 1

  prefixo="${hash%\$*}"            # "$6$salt"
  calculado="$(openssl passwd -6 -salt "${prefixo#\$6\$}" "$senha" 2>/dev/null)"
  [[ "$calculado" == "$hash" ]]
}

# ------------------------------------------------------------ 1. criar usuário

criar_usuario() {
  exigir_admin || return 1
  local usuario="${1:-}" cpf="${2:-}"

  if [[ -z "$usuario" ]]; then read -rp "Nome do usuário: " usuario; fi
  if ! usuario_valido "$usuario"; then
    msg_erro "nome inválido (use letras minúsculas, números, '_' ou '-', começando por letra ou '_')."
    return 1
  fi
  if usuario_existe "$usuario"; then
    msg_erro "o usuário '$usuario' já existe."
    return 1
  fi

  if [[ -z "$cpf" ]]; then
    read -rsp "CPF (será a senha): " cpf; echo
  fi
  if ! cpf_valido "$cpf"; then
    msg_erro "CPF inválido."
    return 1
  fi
  cpf="$(cpf_normalizar "$cpf")"

  useradd -m -s /bin/bash "$usuario" || { msg_erro "falha ao criar o usuário."; return 1; }
  if ! echo "$usuario:$cpf" | chpasswd -c SHA512; then
    userdel -r "$usuario" &>/dev/null
    msg_erro "falha ao definir a senha; usuário removido."
    return 1
  fi
  msg_ok "usuário '$usuario' criado (senha = CPF, somente dígitos)."
}

# --------------------------------------------------- 2. associar a um grupo

associar_usuario() {
  exigir_admin || return 1
  local usuario="${1:-}" grupo="${2:-}"

  if [[ -z "$usuario" ]]; then read -rp "Usuário: " usuario; fi
  usuario_existe "$usuario" || { msg_erro "usuário '$usuario' não existe."; return 1; }

  if [[ -z "$grupo" ]]; then
    read -rp "Grupo (${GRUPOS_VALIDOS[*]}): " grupo
  fi
  grupo_valido "$grupo" || { msg_erro "grupo inválido. Opções: ${GRUPOS_VALIDOS[*]}"; return 1; }

  if usuario_no_grupo "$usuario" "$grupo"; then
    msg_erro "'$usuario' já pertence ao grupo '$grupo'."
    return 1
  fi
  gpasswd -a "$usuario" "$grupo" &>/dev/null \
    && msg_ok "'$usuario' adicionado ao grupo '$grupo'." \
    || { msg_erro "falha ao associar."; return 1; }
}

# -------------------------------------------------- 3. desassociar de um grupo

desassociar_usuario() {
  exigir_admin || return 1
  local usuario="${1:-}" grupo="${2:-}"

  if [[ -z "$usuario" ]]; then read -rp "Usuário: " usuario; fi
  usuario_existe "$usuario" || { msg_erro "usuário '$usuario' não existe."; return 1; }

  if [[ -z "$grupo" ]]; then
    read -rp "Grupo (${GRUPOS_VALIDOS[*]}): " grupo
  fi
  grupo_valido "$grupo" || { msg_erro "grupo inválido. Opções: ${GRUPOS_VALIDOS[*]}"; return 1; }

  if ! usuario_no_grupo "$usuario" "$grupo"; then
    msg_erro "'$usuario' não pertence ao grupo '$grupo'."
    return 1
  fi
  if [[ "$grupo" == "$GRUPO_ADMIN" ]] && (($(contar_admins) <= 1)); then
    msg_erro "'$usuario' é o último admin; não é possível removê-lo do grupo."
    return 1
  fi
  gpasswd -d "$usuario" "$grupo" &>/dev/null \
    && msg_ok "'$usuario' removido do grupo '$grupo'." \
    || { msg_erro "falha ao desassociar."; return 1; }
}

# ------------------------------------------------------- 4. excluir usuário

excluir_usuario() {
  exigir_admin || return 1
  local usuario="${1:-}" conf uid

  if [[ -z "$usuario" ]]; then read -rp "Usuário a excluir: " usuario; fi
  usuario_existe "$usuario" || { msg_erro "usuário '$usuario' não existe."; return 1; }

  uid="$(id -u "$usuario")"
  if ((uid < 1000)); then
    msg_erro "não é permitido excluir usuários de sistema (UID < 1000)."
    return 1
  fi
  if [[ "$usuario" == "$USUARIO_ATUAL" ]]; then
    msg_erro "você não pode excluir o usuário com o qual está logado."
    return 1
  fi
  if usuario_no_grupo "$usuario" "$GRUPO_ADMIN" && (($(contar_admins) <= 1)); then
    msg_erro "'$usuario' é o último admin; não pode ser excluído."
    return 1
  fi

  read -rp "Excluir '$usuario' e o diretório home? (s/N) " conf
  [[ "$conf" =~ ^[sSyY]$ ]] || { echo "cancelado."; return 1; }

  userdel -r "$usuario" &>/dev/null \
    && msg_ok "usuário '$usuario' excluído." \
    || { msg_erro "falha ao excluir (o usuário pode ter processos ativos)."; return 1; }
}

# ----------------------------------------------------------------- extras

listar_usuarios() {
  local g membros
  for g in "${GRUPOS_VALIDOS[@]}"; do
    membros="$(getent group "$g" | cut -d: -f4)"
    printf '%-14s %s\n' "$g" "${membros:--}"
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "auth.sh é uma biblioteca. Execute ./main.sh"
  exit 1
fi

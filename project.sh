#!/usr/bin/env bash
# project.sh - gerenciamento de projetos
#
# Estrutura criada para cada projeto:
#   <PROJETOS_DIR>/<nome>/
#       bancodedados/   -> grupo bancodedados + admin
#       frontend/       -> grupo frontend      + admin
#       backend/        -> grupo backend       + admin
#
# Requer root e o pacote "acl" (setfacl).

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=auth.sh
source "$DIR_SCRIPT/auth.sh"

PROJETOS_DIR="${PROJETOS_DIR:-/srv/projetos}"
SUBPASTAS=(bancodedados frontend backend)   # o nome da pasta = nome do grupo

projeto_nome_valido() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; }

# Qualquer usuário logado que pertença a algum grupo pode criar projetos.
exigir_algum_grupo() {
  [[ "$MODO_BOOTSTRAP" == "1" ]] && return 0
  local g
  for g in "${GRUPOS_VALIDOS[@]}"; do
    [[ -n "$USUARIO_ATUAL" ]] && usuario_no_grupo "$USUARIO_ATUAL" "$g" && return 0
  done
  msg_erro "você precisa pertencer a pelo menos um grupo para criar projetos."
  return 1
}

# ------------------------------------------------------------ 1. criar projeto

criar_projeto() {
  exigir_algum_grupo || return 1
  local nome="${1:-}" dir sub

  if [[ -z "$nome" ]]; then read -rp "Nome do projeto: " nome; fi
  if ! projeto_nome_valido "$nome"; then
    msg_erro "nome inválido (use letras, números, '.', '_' ou '-', começando por letra/número)."
    return 1
  fi
  command -v setfacl &>/dev/null || { msg_erro "setfacl não encontrado (instale o pacote 'acl')."; return 1; }
  garantir_grupos || return 1

  dir="$PROJETOS_DIR/$nome"
  if [[ -e "$dir" ]]; then
    msg_erro "o projeto '$nome' já existe."
    return 1
  fi

  # diretório base: apenas atravessável por todos
  mkdir -p "$PROJETOS_DIR" && chown root:root "$PROJETOS_DIR" && chmod 755 "$PROJETOS_DIR" || return 1

  # pasta do projeto: admin lista; os demais só atravessam (x) até a subpasta do seu grupo
  mkdir "$dir" || return 1
  chown root:"$GRUPO_ADMIN" "$dir"
  chmod 755 "$dir"

  for sub in "${SUBPASTAS[@]}"; do
    mkdir "$dir/$sub"
    chown root:"$sub" "$dir/$sub"
    chmod 2770 "$dir/$sub"   # setgid: arquivos novos herdam o grupo; "outros" sem acesso
    # admin tem acesso total a todas as subpastas (e ao que for criado dentro delas)
    setfacl -m "g:$GRUPO_ADMIN:rwx,d:g:$GRUPO_ADMIN:rwx,d:g:$sub:rwx" "$dir/$sub" \
      || { msg_erro "falha ao aplicar ACL em '$dir/$sub'."; rm -rf -- "$dir"; return 1; }
  done

  msg_ok "projeto '$nome' criado em $dir"
}

# ----------------------------------------------------------- 2. excluir projeto

excluir_projeto() {
  # somente membros do grupo admin
  if [[ "$MODO_BOOTSTRAP" != "1" ]]; then
    if [[ -z "$USUARIO_ATUAL" ]] || ! usuario_no_grupo "$USUARIO_ATUAL" "$GRUPO_ADMIN"; then
      msg_erro "somente membros do grupo '$GRUPO_ADMIN' podem excluir projetos."
      return 1
    fi
  fi

  local nome="${1:-}" dir conf
  if [[ -z "$nome" ]]; then read -rp "Projeto a excluir: " nome; fi
  projeto_nome_valido "$nome" || { msg_erro "nome de projeto inválido."; return 1; }

  dir="$PROJETOS_DIR/$nome"
  if [[ ! -d "$dir" || -L "$dir" ]]; then
    msg_erro "o projeto '$nome' não existe."
    return 1
  fi

  read -rp "Digite o nome do projeto para confirmar a exclusão: " conf
  [[ "$conf" == "$nome" ]] || { echo "cancelado."; return 1; }

  rm -rf -- "$dir" && msg_ok "projeto '$nome' excluído." || { msg_erro "falha ao excluir."; return 1; }
}

# ---------------------------------------------------------------------- extra

listar_projetos() {
  if [[ ! -d "$PROJETOS_DIR" ]] || [[ -z "$(ls -A "$PROJETOS_DIR" 2>/dev/null)" ]]; then
    echo "(nenhum projeto)"
    return 0
  fi
  ls -1 "$PROJETOS_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "project.sh é uma biblioteca. Execute ./main.sh"
  exit 1
fi

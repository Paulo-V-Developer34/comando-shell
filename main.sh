#!/usr/bin/env bash
# main.sh - REPL que organiza auth.sh e project.sh
#
# Uso: sudo ./main.sh
# Dependências: useradd, usermod, gpasswd, userdel, chpasswd, openssl, setfacl (pacote acl)

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=auth.sh
source "$DIR_SCRIPT/auth.sh"
# shellcheck source=project.sh
source "$DIR_SCRIPT/project.sh"

verificar_ambiente() {
  if [[ $EUID -ne 0 ]]; then
    echo "Execute como root: sudo ./main.sh" >&2
    exit 1
  fi
  local cmd faltando=()
  for cmd in useradd usermod gpasswd userdel chpasswd groupadd getent openssl setfacl; do
    command -v "$cmd" &>/dev/null || faltando+=("$cmd")
  done
  if ((${#faltando[@]})); then
    echo "Comandos ausentes: ${faltando[*]}" >&2
    echo "Dica (Debian/Ubuntu): sudo apt install acl openssl passwd" >&2
    exit 1
  fi
}

# Se ainda não existe nenhum admin, cria o primeiro.
bootstrap_admin() {
  ((($(contar_admins)) > 0)) && return 0

  echo "Nenhum usuário no grupo '$GRUPO_ADMIN' foi encontrado."
  echo "Vamos criar o primeiro administrador."
  MODO_BOOTSTRAP=1
  local usuario
  while true; do
    read -rp "Nome do admin: " usuario
    if criar_usuario "$usuario" && associar_usuario "$usuario" "$GRUPO_ADMIN"; then
      break
    fi
    usuario_existe "$usuario" && usuario_no_grupo "$usuario" "$GRUPO_ADMIN" && break
  done
  MODO_BOOTSTRAP=0
}

login() {
  local tentativas=0 usuario senha
  while ((tentativas < 3)); do
    read -rp "Usuário: " usuario
    read -rsp "Senha (CPF): " senha; echo
    if autenticar "$usuario" "$senha"; then
      USUARIO_ATUAL="$usuario"
      echo "Bem-vindo, $USUARIO_ATUAL!"
      return 0
    fi
    msg_erro "usuário ou senha incorretos."
    tentativas=$((tentativas + 1))
  done
  return 1
}

ajuda() {
  cat <<'EOF'

Comandos (digite o número ou o nome):
  1  criar-usuario        cria usuário (senha = CPF validado)
  2  associar             adiciona usuário a um grupo
  3  desassociar          remove usuário de um grupo
  4  excluir-usuario      exclui usuário
  5  criar-projeto        cria projeto com bancodedados/frontend/backend
  6  excluir-projeto      exclui projeto (somente admin)
  7  listar-projetos
  8  listar-grupos        mostra os membros de cada grupo
  9  ajuda
  0  sair

Grupos: admin, bancodedados, frontend, backend
EOF
  echo
}

repl() {
  local cmd
  ajuda
  while true; do
    read -rep "[$USUARIO_ATUAL]> " cmd || { echo; break; }
    case "$cmd" in
      1|criar-usuario)      criar_usuario ;;
      2|associar)           associar_usuario ;;
      3|desassociar)        desassociar_usuario ;;
      4|excluir-usuario)    excluir_usuario ;;
      5|criar-projeto)      criar_projeto ;;
      6|excluir-projeto)    excluir_projeto ;;
      7|listar-projetos)    listar_projetos ;;
      8|listar-grupos)      listar_usuarios ;;
      9|ajuda|help|"?")     ajuda ;;
      0|sair|exit|quit)     echo "Até logo!"; break ;;
      "")                   ;;
      *)                    msg_erro "comando desconhecido: '$cmd' (digite 'ajuda')." ;;
    esac
  done
}

main() {
  verificar_ambiente
  garantir_grupos || { echo "Não foi possível criar os grupos." >&2; exit 1; }
  bootstrap_admin
  login || { echo "Número máximo de tentativas excedido." >&2; exit 1; }
  repl
}

main "$@"

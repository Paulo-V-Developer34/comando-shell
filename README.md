# Projeto de SO II

O projeto consiste em um script bash que cria projetos e gerencia o acesso, funciona tanto em distribuições baseadas no debian quanto baseadas no alpine

## Usando Docker

1. Subir o contêiner e o volume

```bash
# Debian (padrão)
docker compose run --name teste-bash --build app

# Alpine
BASE_IMAGE=alpine:3.20 docker compose run --name teste-bash --build app
```

2. Entrar no contêiner

```bash
docker start -ai teste-bash
```

## Usando VM

1. Inicie qualquer distribuição linux baseada no Debian, como o Ubuntu.

2. Passe os 3 arquivos para a VM

3. Instale as dependências

```bash
sudo apt install acl openssl passwd
```

4. Execute
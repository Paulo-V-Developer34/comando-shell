# Projeto de SO II

O projeto consiste em um script bash que cria projetos e gerencia o acesso

## Usando Docker

1. Subir o contêiner e o volume

```bash
# Debian (padrão)
docker compose run --rm --name teste-bash --build app

# Alpine
BASE_IMAGE=alpine:3.20 docker compose run --rm --name teste-bash --build app
```

2. Entrar no contêiner

```bash
docker exec -it debian-test bash
```

## Usando VM

1. Inicie qualquer distribuição linux baseada no Debian, como o Ubuntu.

2. Passe os 3 arquivos para a VM

3. Instale as dependências

```bash
sudo apt install acl openssl passwd
```

4. Execute
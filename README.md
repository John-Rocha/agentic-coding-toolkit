# Agentic Coding Toolkit (Lite)

Conjunto de skills de agente que leva uma feature de ideia bruta a código entregue, com fluxo estruturado e revisável: **Interview → Spec → Refine → Work Items → Implement**.

Funciona com Claude Code, OpenCode, Cursor, Codex, Gemini e Antigravity.

Repositório: https://github.com/John-Rocha/agentic-coding-toolkit

## Fluxo de trabalho

```
act-interview       Resolve intenção, linguagem e restrições antes de escrever a Spec
      ↓
act-create-spec     Transforma o contexto resolvido em uma Spec + Interview Ledger
      ↓
act-refine-spec     Revisão adversarial: contradições, lacunas, desalinhamento com o código
      ↓
act-create-issues   Decompõe uma Spec aprovada em Work Items independentes
      ↓
act-implement       Implementa um Work Item (ou uma Spec pequena direto), TDD quando possível
```

Specs pequenas e de baixo risco podem pular direto de `act-refine-spec` para `act-implement`, sem passar por `act-create-issues`.

## Skills

| Skill | Função |
|---|---|
| [`act-config`](skills/act-config/SKILL.md) | Configura o armazenamento do workflow (GitHub Issues ou markdown local) para o diretório atual |
| [`act-interview`](skills/act-interview/SKILL.md) | Faz uma pergunta por vez para resolver intenção, terminologia e dependências de decisão |
| [`act-create-spec`](skills/act-create-spec/SKILL.md) | Salva uma Spec + Interview Ledger a partir do contexto da conversa |
| [`act-refine-spec`](skills/act-refine-spec/SKILL.md) | Revisa uma Spec em busca de contradições, lacunas e suposições erradas antes da decomposição |
| [`act-create-issues`](skills/act-create-issues/SKILL.md) | Transforma uma Spec aprovada em Work Items executáveis de forma independente |
| [`act-implement`](skills/act-implement/SKILL.md) | Implementa um Work Item ou Spec com TDD e análise estática |
| [`act-update`](skills/act-update/SKILL.md) | Verifica e aplica atualizações do ACT Lite a partir do GitHub |

Specs ficam armazenadas por diretório em `.act/config.yaml` (backend: `github` ou `local`, ver [act-config](skills/act-config/SKILL.md)), com a semântica documentada em `.act/workflow.md`.

## Instalação

```bash
git clone https://github.com/John-Rocha/agentic-coding-toolkit.git ~/.agentic-coding-toolkit-lite
cd ~/.agentic-coding-toolkit-lite

./scripts/install.sh --tool claude       # Claude Code
./scripts/install.sh --tool opencode     # OpenCode
./scripts/install.sh --tool cursor       # Cursor
./scripts/install.sh --tool codex        # Codex
./scripts/install.sh --tool gemini       # Gemini
./scripts/install.sh --tool antigravity  # Antigravity
```

O instalador cria symlinks das skills no diretório de config da ferramenta alvo (ou copia e transforma para o Codex) e instala um helper de runtime compartilhado em `~/.config/agentic-coding-toolkit/bin/act-run-script.js`. Reinicie a CLI/editor afetado depois de instalar.

Para remover:

```bash
./scripts/uninstall.sh --tool <claude|opencode|cursor|codex|gemini|antigravity>
```

Para atualizar para a versão mais recente, rode a skill `act-update` de dentro da sua ferramenta de agente, ou `git pull origin main` em `~/.agentic-coding-toolkit-lite` seguido de `install.sh` novamente.

## Estrutura do repositório

```
skills/           Definições das skills (SKILL.md + references/ + scripts/)
scripts/          install.sh, uninstall.sh, helpers Node compartilhados, testes
VERSION           Versão atual do toolkit
```

## Desenvolvimento

```bash
node scripts/tests/validate-toolkit.test.js
```

## Licença

[MIT](LICENSE)

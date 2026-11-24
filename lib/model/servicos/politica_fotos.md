# Política de Retenção e Limpeza de Fotos Locais

Este documento define as regras de gerenciamento, retenção e ciclo de vida de imagens no aplicativo de receitas.

---

## 1. Localização e Referência

- As fotos de receitas próprias salvas localmente são copiadas para a subpasta `fotos_receitas/` no diretório de documentos do aplicativo (`getApplicationDocumentsDirectory()`).
- O banco de dados armazena em `versao_receita.foto_local` exclusivamente um **caminho relativo** (ex: `fotos_receitas/<uuid>.jpg`), garantindo portabilidade caso o caminho raiz do aplicativo mude entre execuções ou atualizações do sistema operacional.

---

## 2. Imutabilidade e Preservação Histórica

- **Nunca apagar arquivos ainda referenciados:** Se uma imagem estiver vinculada a qualquer `versao_receita` (seja versão 1, 2 ou anterior), ela **NÃO pode ser apagada**, mesmo que uma edição posterior tenha trocado ou removido a foto na versão mais recente.
- **Exclusão Lógica de Receita:** Quando uma receita é excluída logicamente (`excluida_em IS NOT NULL`), os arquivos de foto permanecem preservados no aparelho para sustentar o histórico de preparos e conferências passadas.

---

## 3. Limpeza Após Falhas

- Caso a cópia física do arquivo seja realizada, mas a transação subsequente no SQLite falhe (rollback), o `GerenciadorFotos` deve remover imediatamente o arquivo recém-copiado (`limparCopiaRecente`) para evitar arquivos órfãos não catalogados.
- Futuras rotinas de manutenção ou limpeza de armazenamento devem verificar exaustivamente a tabela `versao_receita` antes de expurgar qualquer imagem não referenciada.

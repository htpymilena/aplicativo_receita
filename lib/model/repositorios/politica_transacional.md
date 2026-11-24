# Política de Gravação Transacional e Cardinalidades Mínimas (SQLite v1)

Este documento registra as regras transacionais e cardinalidades mínimas estabelecidas na **Etapa 1**, que devem ser seguidas rigorosamente pelos repositórios das próximas etapas (Etapas 2, 3 e posteriores).

---

## 1. Cardinalidades Mínimas do MER

Como restrições `CHECK` a nível de linha no SQLite operam individualmente por inserção, a integridade de conjuntos agregados deve ser garantida por **transações atômicas no repositório**:

1. **Receita e Versão:**
   - Toda receita deve ser persistida juntamente com sua versão inicial (`numero_versao = 1`) em uma única transação (`db.transaction`).
   - Se a criação da versão falhar, a receita não é gravada.

2. **Versão, Itens e Etapas (Etapa 2):**
   - Uma versão de receita deve possuir obrigatoriamente:
     - No mínimo **1 ingrediente / item de receita** (`item_receita`) com medida válida (ou "a gosto").
     - No mínimo **1 etapa de instrução** (`etapa`).
   - O repositório de receitas deve validar a presença de ao menos 1 item e 1 etapa antes de efetivar o `commit`.

3. **Preparo e Conferências (Etapa 3):**
   - Ao iniciar um preparo para determinada versão, o repositório de preparos deve criar transacionalmente:
     - 1 registro em `preparo` apontando para a `versao_receita` e definindo `ordem_etapa_atual = 1`.
     - 1 registro em `conferencia` para **cada** `item_receita` existente naquela versão, com estado inicial `'nao_conferido'`.

4. **Avaliação por Preparo:**
   - A avaliação (`avaliacao`) tem como chave primária o `id_preparo`, garantindo que cada preparo só receba no máximo uma avaliação.
   - Apenas preparos concluídos (`concluido_em IS NOT NULL`) podem receber avaliação.

---

## 2. Regras de Integridade e Triggers do Esquema

O esquema SQLite v1 inclui as seguintes proteções ativas:
- `PRAGMA foreign_keys = ON;` configurado em todas as conexões.
- Chaves estrangeiras com `ON DELETE RESTRICT`, impedindo exclusões acidentais em cascata que corrompam o histórico de preparos e favoritos.
- Exclusão lógica através do campo `excluida_em` em `receita`.
- `trg_conferencia_versao_check_insert` e `trg_conferencia_versao_check_update`: garantem que uma conferência só aponte para um item pertencente à mesma versão orientada pelo preparo.
- `trg_preparo_etapa_atual_check_insert` e `trg_preparo_etapa_atual_check_update`: garantem que a `ordem_etapa_atual` informada no preparo exista como etapa cadastrada na versão.

---

## 3. Política de Atualização e Migração (Upgrade)

- A versão do esquema é controlada pelo `PRAGMA user_version` através do `sqflite`.
- O gancho `_aoAtualizar(db, versaoAntiga, versaoNova)` implementa migrações incrementais (ex: `ALTER TABLE`), preservando os registros de dados existentes sem executar `DROP TABLE` em upgrades normais.

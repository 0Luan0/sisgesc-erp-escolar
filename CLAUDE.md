# CLAUDE.md — SisGESC ERP Escolar

## Estado atual do projeto

Projeto de banco de dados relacional (MySQL 8+) para avaliação acadêmica (banca técnica — Unicid/SENAC).
Entrega pendente. Projeto testado e funcionando do zero em MySQL 9.7.0 (Mac) e compatível com MySQL 8.0 (Windows).

**Status:** pronto para entrega. Todos os arquivos estão no GitHub: https://github.com/0Luan0/sisgesc-erp-escolar

---

## Arquivos do projeto

| Arquivo | Conteúdo |
|---|---|
| `run_all.sql` | Ponto de entrada único — concatenação dos 7 arquivos abaixo, sem SOURCE |
| `01_ddl_estrutura.sql` | DDL completo: 33 tabelas, views, 14 triggers |
| `02_dml_carga.sql` | Carga de dados (INSERT IGNORE) |
| `03_oltp_consultas.sql` | 12 consultas OLTP + demonstração ACID |
| `04_olap_star_schema.sql` | Star schema (banco erp_escolar_olap) |
| `05_etl_carga_olap.sql` | ETL full reload OLTP → OLAP |
| `06_validacao.sql` | Índices, EXPLAIN antes/depois, validação SUM OLTP = OLAP |
| `07_reset.sql` | DROP DATABASE erp_escolar e erp_escolar_olap |
| `docs/dicionario_dados.md` | Dicionário de dados completo |

**IMPORTANTE:** sempre que alterar qualquer dos 7 arquivos individuais, regenerar o `run_all.sql`:
```bash
cat 07_reset.sql 01_ddl_estrutura.sql 02_dml_carga.sql 03_oltp_consultas.sql \
    04_olap_star_schema.sql 05_etl_carga_olap.sql 06_validacao.sql > run_all.sql
```

---

## Como testar localmente (Mac)

```bash
cp "/Users/luanlucena/Documents/Claude/Projects/Banco de Dados/run_all.sql" /tmp/run_all.sql
/usr/local/mysql/bin/mysql -u root -p
```

Dentro do MySQL (senha: Enter sem digitar nada):
```sql
SOURCE /tmp/run_all.sql
```

O MySQL está em `/usr/local/mysql/bin/mysql`. O SOURCE não aceita caminhos com espaço — por isso o cp para /tmp.

---

## Resultado esperado após execução limpa

- **33 tabelas** em `erp_escolar`
- **10 tabelas** em `erp_escolar_olap` (6 dims + 4 fatos)
- `ferias`: 3 registros, `conjuge_funcionario`: 2 registros
- Validação financeira: `soma_oltp = soma_olap = 36387.50`, `diferenca = 0.00`
- ACID: rollback → 8 alunos antes = 8 depois; commit → A0000009 persiste

---

## Bugs corrigidos nesta sessão (histórico)

| Bug | Causa | Correção |
|---|---|---|
| `ferias` vazia após DML | Datas fora do `periodo_aquisitivo` — trigger rejeitava via INSERT IGNORE | Corrigidas as datas e referências de período |
| ERROR 1146 `conjuge_funcionario doesn't exist` | `DEFAULT (CURRENT_DATE)` parava o DDL antes de chegar na tabela | Removido o DEFAULT da coluna `data_solicitacao` em `abono_ferias` |
| ERROR 3823 | `fk_rgf_1/fk_rgf_2` usadas em CHECK constraint + FK com ON UPDATE CASCADE — MySQL não permite | Trocado para ON UPDATE RESTRICT em `conjuge_funcionario` |
| ACID Cenário 1 e 2 falhavam | RGA 'A0000001' já existia (Joao Santos) — INSERT duplicado | Trocado para 'A0000009' |
| `SOURCE` não funcionava com `<` redirecionamento | SOURCE é comando interativo do MySQL, não suporta stdin | `run_all.sql` gerado como arquivo único sem SOURCE |
| `CREATE INDEX IF NOT EXISTS` falhava | Sintaxe inválida no MySQL (não existe) | Removido o `IF NOT EXISTS` de todos os CREATE INDEX |
| SOURCE com espaço no caminho falhava | SOURCE não aceita espaços no path nem com aspas nem com backslash | Copiar para /tmp antes de rodar |

---

## Critérios de modelagem (lei do projeto)

1. **1FN/2FN/3FN** obrigatórios em todas as tabelas
2. **PK natural** quando estável/imutável/controlada pelo sistema (rga, rgf, codigo_curso)
3. **PK composta** em N:N simples (curso_materia, matricula_turma)
4. **PK surrogate** quando composta teria 4+ campos e seria usada como FK
5. **Tabelas de domínio separadas por contexto** (status_aluno, status_matricula — nunca unificadas)
6. **Campos derivados nunca armazenados** — viram VIEW (nota_final, salario_liquido)
7. **Regras de negócio** via CHECK, UNIQUE documentado, ou trigger
8. **Nomenclatura:** tabelas snake_case singular, FKs `fk_<campo>`, surrogates `pk_id_<entidade>`

---

## Decisões de design já tomadas (não alterar)

- Financeiro: `matricula → contrato → mensalidade → pagamento`
- Professor é papel de funcionário (PK herdada, não entidade independente)
- Calendário acadêmico: `fk_curso NULL` = institucional; PK surrogate (nullable impede composta)
- Grade curricular versionada: `curso_materia` (base) + `curso_materia_revisao` (alterações)
- `folha_evento.valor` sempre positivo; sinal determinado por `evento_folha.tipo`
- Pix/Boleto delegados a API externa — banco guarda apenas `id_transacao_externo`
- Holerite é relatório, não tabela
- `dim_unidade` não existe no OLTP — criada no ETL por mapeamento curso → área acadêmica

---

## Dialeto e restrições técnicas

- MySQL 8+ (utf8mb4_unicode_ci)
- UNIQUE parcial (WHERE) não existe no MySQL — documentar como comentário e sugerir trigger
- `CREATE INDEX IF NOT EXISTS` não existe no MySQL — usar `CREATE INDEX` simples
- `DEFAULT (CURRENT_DATE)` com parênteses requer MySQL 8.0.13+ mas causa problemas — evitar
- `ON UPDATE CASCADE` em FK cujas colunas aparecem em CHECK constraint gera ERROR 3823 — usar RESTRICT
- Todo código deve ser executável diretamente sem erros de sintaxe

# Composable Semantic Views Demo

This project demonstrates **composable semantic views** in Snowflake — a feature that lets you build layered, reusable semantic models using the `IMPORTS` clause. Shared dimensions are defined once and inherited by domain-specific and executive-level views through transitive imports.

## Architecture

The demo uses a gaming console business scenario with a 3-layer import hierarchy:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 3: SV_EXECUTIVE                                               │
│   imports SV_ENGAGEMENT → transitive to Layer 1                     │
│   Adds: M_SESSIONS_PER_PLAYER (new metric on imported entity)       │
└─────────────────────────┬───────────────────────────────────────────┘
                          │ IMPORTS
┌─────────────────────────┴───────────────────────────────────────────┐
│ Layer 2: Domain Semantic Views                                       │
│                                                                      │
│  SV_ENGAGEMENT          SV_STORE             SV_SUPPORT             │
│  ├─ imports L1          ├─ imports L1         ├─ imports SV_PLAYERS  │
│  └─ GAME_SESSIONS       ├─ PURCHASES          └─ SUPPORT_TICKETS   │
│                         └─ SUBSCRIPTIONS                            │
└──────────┬─────────────────────┬────────────────────┬───────────────┘
           │                     │                    │
┌──────────┴─────────────────────┴────────────────────┴───────────────┐
│ Layer 1: Shared Dimensions                                           │
│                                                                      │
│  SV_PLAYERS              SV_CONSOLE_CATALOG                         │
│  (15 players)            (5 consoles, 10 games)                     │
└─────────────────────────────────────────────────────────────────────┘
```

## What's Demonstrated

| # | Feature | Where |
|---|---------|-------|
| 1 | `IMPORTS` clause | All Layer 2 + Layer 3 SVs |
| 2 | All-or-nothing import | `SV_ENGAGEMENT` imports 2 full SVs |
| 3 | Local tables alongside imports | Layer 2 SVs add their own tables |
| 4 | New metrics on imported entities | `SV_EXECUTIVE.M_SESSIONS_PER_PLAYER` |
| 5 | Relationships using logical names | `SESSIONS_TO_PLAYERS`, etc. |
| 6 | Transitive imports (3 levels deep) | Executive → Engagement → Players/Catalog |
| 7 | Late binding (runtime resolution) | Add dimension to source, query through 3 layers instantly |
| 8 | Privilege resolution | `GAMING_ANALYST` role with `REFERENCES + SELECT` only |
| 9 | YAML `imports` block | `SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW` output |
| 10 | `is_imported: true` shadow tables | YAML output |
| 11 | `DESCRIBE SEMANTIC VIEW` metadata | Introspection queries |
| 12 | `SHOW SEMANTIC VIEWS` imports column | Introspection queries |
| 13 | `GET_DDL` with IMPORTS clause | Governance demo |
| 14 | `SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW` | Full transitive model inspection |
| 15 | Query: imported dimension + local metric | `SV_STORE` with `PLAYERS.D_REGION` |
| 16 | Query: imported metric from composed view | `SV_EXECUTIVE` accessing engagement metrics |
| 17 | Query: mix imported + local dimensions | Combined cross-layer queries |

## Files

| File | Description |
|------|-------------|
| `composable_sv_demo.sql` | End-to-end SQL script: creates schema, tables, all 6 semantic views, demo queries, introspection, late binding, and privilege resolution |
| `composable_sv_notebook.ipynb` | Interactive Snowflake notebook with visualizations (Sankey diagrams, heatmaps, bar charts) exploring the composition hierarchy |
| `GAMING_AGENT.agent.yaml` | Cortex Agent definition that wires each semantic view as a tool, demonstrating how agents use composable SVs for multi-domain Q&A |
| `composable-semantic-views.pdf` | Slide deck / reference material |

## Getting Started

### Prerequisites

- A Snowflake account with `ACCOUNTADMIN` (or a role with `CREATE SEMANTIC VIEW`)
- A warehouse (the scripts use `COMPUTE_WH`)

### Setup

1. Run the SQL setup script to create all objects:
   ```sql
   -- In Snowsight or any SQL client
   USE ROLE ACCOUNTADMIN;
   -- Execute composable_sv_demo.sql
   ```

2. Open `composable_sv_notebook.ipynb` in Snowflake Notebooks (Snowsight) to run the interactive demo with visualizations.

3. Optionally, deploy the Cortex Agent using `GAMING_AGENT.agent.yaml` to chat with the composed semantic model.

## Key Design Constraints

- **No diamond imports** — Two paths to the same ancestor SV are prohibited
- **PK dimension naming** — Dimension for a PK column must share its name (e.g., `PLAYER_ID` dimension = `PLAYERS.PLAYER_ID` expression)
- **Imported entity metrics** — Can only reference imported calculations (dimensions/metrics), not physical columns
- **Late binding is instant** — `CREATE OR REPLACE` on a source SV propagates to all consumers with no recreation needed

## Cross-Domain Query Patterns

**Vertical traversal** — A top-level view reaches down through multiple import layers:
```sql
SELECT * FROM SEMANTIC_VIEW(
    SV_EXECUTIVE
    DIMENSIONS PLAYERS.D_REGION        -- from Layer 1 (2 levels deep)
    METRICS GAME_SESSIONS.M_SESSIONS_PER_PLAYER  -- from Layer 3
);
```

**Horizontal sharing** — Domain views import sibling base-layer views:
```sql
SELECT * FROM SEMANTIC_VIEW(
    SV_STORE
    DIMENSIONS PLAYERS.D_REGION, PURCHASES.D_PURCHASE_TYPE
    METRICS PURCHASES.M_TOTAL_REVENUE
);
```

/*******************************************************************************
 * COMPOSABLE SEMANTIC VIEWS — GAMING CONSOLE BUSINESS DEMO
 *
 * Demonstrates every feature of composable semantic views using a gaming
 * console business scenario with a 3-layer import architecture:
 *
 *   Layer 1: SV_PLAYERS, SV_CONSOLE_CATALOG (shared dimensions)
 *   Layer 2: SV_ENGAGEMENT, SV_STORE, SV_SUPPORT (domain SVs importing Layer 1)
 *   Layer 3: SV_EXECUTIVE (imports SV_ENGAGEMENT → transitive to Layer 1)
 *
 * Features demonstrated:
 *   1.  IMPORTS clause
 *   2.  All-or-nothing import
 *   3.  Local tables alongside imports
 *   4.  New metrics on imported entities (shadow tables)
 *   5.  Relationships on imported entities using logical names
 *   6.  Transitive imports (3 levels deep)
 *   7.  Late binding (runtime resolution)
 *   8.  Privilege resolution
 *   9.  YAML format (imports block)
 *   10. is_imported: true shadow tables in YAML
 *   11. DESCRIBE SEMANTIC VIEW metadata
 *   12. SHOW SEMANTIC VIEWS imports column
 *   13. GET_DDL output with IMPORTS clause
 *   14. SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW
 *   15. Query: imported dimension + local metric
 *   16. Query: imported metric from composed view
 *   17. Query: mix imported + local dimensions
 *
 * IMPORTANT NOTES ON COMPOSABLE SV CONSTRAINTS:
 *   - Diamond imports are NOT allowed: if two imported SVs share a common
 *     ancestor, you cannot import both into the same composed view.
 *   - Relationships referencing imported entities must use the DIMENSION name
 *     (a calculation), not the raw physical column name.
 *   - Metrics on imported entities can only reference imported calculations
 *     (dimensions/metrics), not physical columns.
 *   - The dimension that maps to the PK column should be named identically
 *     to the PK column (e.g., PLAYER_ID dimension = PLAYERS.PLAYER_ID expr)
 *     so relationships can reference it as both a calculation and PK.
 ******************************************************************************/

-- ============================================================================
-- SETUP: Schema and Physical Tables
-- ============================================================================

USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS DEMO_DB;
CREATE SCHEMA IF NOT EXISTS DEMO_DB.GAMING;
USE SCHEMA DEMO_DB.GAMING;
USE WAREHOUSE COMPUTE_WH;

-- Drop existing objects for idempotency (reverse dependency order)
DROP SEMANTIC VIEW IF EXISTS SV_EXECUTIVE;
DROP SEMANTIC VIEW IF EXISTS SV_ENGAGEMENT;
DROP SEMANTIC VIEW IF EXISTS SV_STORE;
DROP SEMANTIC VIEW IF EXISTS SV_SUPPORT;
DROP SEMANTIC VIEW IF EXISTS SV_PLAYERS;
DROP SEMANTIC VIEW IF EXISTS SV_CONSOLE_CATALOG;

DROP TABLE IF EXISTS SUPPORT_TICKETS;
DROP TABLE IF EXISTS SUBSCRIPTIONS;
DROP TABLE IF EXISTS PURCHASES;
DROP TABLE IF EXISTS GAME_SESSIONS;
DROP TABLE IF EXISTS GAMES;
DROP TABLE IF EXISTS CONSOLES;
DROP TABLE IF EXISTS PLAYERS;

-- ---------------------------------------------------------------------------
-- Table: PLAYERS — Core player dimension (15 rows)
-- ---------------------------------------------------------------------------
CREATE TABLE PLAYERS (
    PLAYER_ID       INTEGER,
    GAMER_TAG       VARCHAR(50),
    REGION          VARCHAR(20),
    TIER            VARCHAR(10),
    SIGNUP_DATE     DATE,
    EMAIL           VARCHAR(100)
);

INSERT INTO PLAYERS VALUES
(1,  'ShadowBlade99',   'NA',   'Gold',     '2022-01-15', 'shadow99@email.com'),
(2,  'PixelQueen',      'EU',   'Platinum', '2021-06-20', 'pqueen@email.com'),
(3,  'ThunderStrike',   'NA',   'Silver',   '2023-03-10', 'tstrike@email.com'),
(4,  'NeonSamurai',     'APAC', 'Gold',     '2022-08-05', 'nsamurai@email.com'),
(5,  'CosmicDrifter',   'EU',   'Platinum', '2021-11-30', 'cdrift@email.com'),
(6,  'IronWolf77',      'NA',   'Bronze',   '2023-09-01', 'iwolf77@email.com'),
(7,  'StargazerX',      'APAC', 'Silver',   '2022-12-15', 'sgazer@email.com'),
(8,  'VortexHunter',    'EU',   'Gold',     '2023-01-22', 'vhunter@email.com'),
(9,  'PhantomAce',      'NA',   'Platinum', '2021-04-18', 'phace@email.com'),
(10, 'BlazeRunner',     'APAC', 'Gold',     '2022-07-09', 'blazer@email.com'),
(11, 'CrystalFox',      'EU',   'Silver',   '2023-05-14', 'cfox@email.com'),
(12, 'TurboNinja',      'NA',   'Gold',     '2022-02-28', 'tninja@email.com'),
(13, 'EchoSpecter',     'APAC', 'Bronze',   '2023-08-20', 'especter@email.com'),
(14, 'FrostByte',       'EU',   'Platinum', '2021-09-12', 'fbyte@email.com'),
(15, 'MaverickPro',     'NA',   'Gold',     '2022-05-03', 'mavpro@email.com');

-- ---------------------------------------------------------------------------
-- Table: CONSOLES — Console hardware catalog (5 rows)
-- ---------------------------------------------------------------------------
CREATE TABLE CONSOLES (
    CONSOLE_ID      INTEGER,
    CONSOLE_NAME    VARCHAR(50),
    MANUFACTURER    VARCHAR(30),
    GENERATION      INTEGER,
    RELEASE_YEAR    INTEGER,
    BASE_PRICE      DECIMAL(8,2)
);

INSERT INTO CONSOLES VALUES
(1, 'PlayStation 5',        'Sony',      9, 2020, 499.99),
(2, 'PlayStation 5 Pro',    'Sony',      9, 2024, 699.99),
(3, 'Xbox Series X',       'Microsoft', 9, 2020, 499.99),
(4, 'Xbox Series S',       'Microsoft', 9, 2020, 299.99),
(5, 'Nintendo Switch 2',   'Nintendo',  9, 2025, 449.99);

-- ---------------------------------------------------------------------------
-- Table: GAMES — Game title catalog (10 rows)
-- ---------------------------------------------------------------------------
CREATE TABLE GAMES (
    GAME_ID         INTEGER,
    GAME_TITLE      VARCHAR(100),
    GENRE           VARCHAR(30),
    CONSOLE_ID      INTEGER,
    RELEASE_DATE    DATE,
    RATING          DECIMAL(3,1)
);

INSERT INTO GAMES VALUES
(1,  'Horizon Forbidden West',  'Action RPG',   1, '2022-02-18', 8.9),
(2,  'God of War Ragnarok',     'Action',       1, '2022-11-09', 9.5),
(3,  'Spider-Man 2',            'Action',       1, '2023-10-20', 9.2),
(4,  'Gran Turismo 7',          'Racing',       1, '2022-03-04', 8.7),
(5,  'Halo Infinite',           'Shooter',      3, '2021-12-08', 8.1),
(6,  'Forza Motorsport',        'Racing',       3, '2023-10-10', 8.4),
(7,  'Starfield',               'RPG',          3, '2023-09-06', 7.5),
(8,  'Zelda: Echoes of Wisdom', 'Adventure',    5, '2024-09-26', 9.0),
(9,  'Astro Bot',               'Platformer',   1, '2024-09-06', 9.4),
(10, 'Final Fantasy XVI',       'Action RPG',   1, '2023-06-22', 8.8);

-- ---------------------------------------------------------------------------
-- Table: GAME_SESSIONS — Player session activity (25 rows)
-- ---------------------------------------------------------------------------
CREATE TABLE GAME_SESSIONS (
    SESSION_ID      INTEGER,
    PLAYER_ID       INTEGER,
    GAME_ID         INTEGER,
    SESSION_DATE    DATE,
    DURATION_MINS   INTEGER,
    ACHIEVEMENTS    INTEGER
);

INSERT INTO GAME_SESSIONS VALUES
(1,  1,  2,  '2024-01-15', 120, 3),
(2,  1,  3,  '2024-01-16', 90,  1),
(3,  2,  1,  '2024-01-15', 180, 5),
(4,  2,  4,  '2024-01-17', 60,  0),
(5,  3,  5,  '2024-01-15', 45,  2),
(6,  3,  6,  '2024-01-18', 75,  1),
(7,  4,  8,  '2024-01-16', 150, 4),
(8,  5,  2,  '2024-01-16', 200, 6),
(9,  5,  9,  '2024-01-19', 110, 3),
(10, 6,  7,  '2024-01-17', 30,  0),
(11, 7,  10, '2024-01-18', 95,  2),
(12, 8,  1,  '2024-01-19', 140, 4),
(13, 9,  3,  '2024-01-20', 85,  2),
(14, 10, 8,  '2024-01-20', 160, 5),
(15, 11, 4,  '2024-01-21', 55,  1),
(16, 12, 2,  '2024-01-21', 175, 4),
(17, 13, 5,  '2024-01-22', 40,  0),
(18, 14, 9,  '2024-01-22', 130, 3),
(19, 15, 6,  '2024-01-23', 70,  1),
(20, 1,  10, '2024-01-23', 100, 2),
(21, 2,  3,  '2024-01-24', 145, 3),
(22, 4,  2,  '2024-01-24', 190, 7),
(23, 6,  9,  '2024-01-25', 65,  1),
(24, 8,  10, '2024-01-25', 80,  2),
(25, 10, 3,  '2024-01-26', 170, 5);

-- ---------------------------------------------------------------------------
-- Table: PURCHASES — Store transactions (20 rows)
-- ---------------------------------------------------------------------------
CREATE TABLE PURCHASES (
    PURCHASE_ID     INTEGER,
    PLAYER_ID       INTEGER,
    GAME_ID         INTEGER,
    CONSOLE_ID      INTEGER,
    PURCHASE_DATE   DATE,
    AMOUNT          DECIMAL(8,2),
    PURCHASE_TYPE   VARCHAR(20)
);

INSERT INTO PURCHASES VALUES
(1,  1,  2,  1, '2022-11-10', 69.99, 'Digital'),
(2,  1,  3,  1, '2023-10-20', 69.99, 'Physical'),
(3,  2,  1,  1, '2022-02-20', 69.99, 'Digital'),
(4,  2,  4,  1, '2022-03-10', 69.99, 'Digital'),
(5,  3,  5,  3, '2021-12-10', 59.99, 'Physical'),
(6,  3,  6,  3, '2023-10-12', 69.99, 'Digital'),
(7,  4,  8,  5, '2024-09-28', 59.99, 'Physical'),
(8,  5,  2,  1, '2022-11-15', 69.99, 'Digital'),
(9,  5,  9,  1, '2024-09-08', 59.99, 'Digital'),
(10, 6,  7,  3, '2023-09-10', 69.99, 'Physical'),
(11, 7,  10, 1, '2023-06-25', 69.99, 'Digital'),
(12, 8,  1,  1, '2022-03-01', 69.99, 'Digital'),
(13, 9,  3,  1, '2023-10-22', 69.99, 'Physical'),
(14, 10, 8,  5, '2024-09-30', 59.99, 'Digital'),
(15, 11, 4,  1, '2022-04-01', 69.99, 'Digital'),
(16, 12, 2,  1, '2022-11-20', 69.99, 'Physical'),
(17, 13, 5,  3, '2022-01-15', 59.99, 'Digital'),
(18, 14, 9,  1, '2024-09-10', 59.99, 'Digital'),
(19, 15, 6,  3, '2023-10-15', 69.99, 'Physical'),
(20, 1,  10, 1, '2023-07-01', 69.99, 'Digital');

-- ---------------------------------------------------------------------------
-- Table: SUBSCRIPTIONS — Recurring subscription services (15 rows)
-- ---------------------------------------------------------------------------
CREATE TABLE SUBSCRIPTIONS (
    SUBSCRIPTION_ID INTEGER,
    PLAYER_ID       INTEGER,
    SERVICE_NAME    VARCHAR(50),
    TIER            VARCHAR(20),
    START_DATE      DATE,
    MONTHLY_COST    DECIMAL(6,2),
    IS_ACTIVE       BOOLEAN
);

INSERT INTO SUBSCRIPTIONS VALUES
(1,  1,  'PS Plus',          'Premium',  '2022-01-20', 17.99, TRUE),
(2,  2,  'PS Plus',          'Extra',    '2021-07-01', 13.99, TRUE),
(3,  3,  'Game Pass',        'Ultimate', '2022-01-01', 16.99, TRUE),
(4,  4,  'Nintendo Online',  'Family',   '2022-09-01', 7.99,  TRUE),
(5,  5,  'PS Plus',          'Premium',  '2021-12-01', 17.99, TRUE),
(6,  6,  'Game Pass',        'Core',     '2023-09-15', 9.99,  TRUE),
(7,  7,  'PS Plus',          'Essential','2023-01-01', 9.99,  TRUE),
(8,  8,  'PS Plus',          'Extra',    '2023-02-01', 13.99, TRUE),
(9,  9,  'PS Plus',          'Premium',  '2021-05-01', 17.99, TRUE),
(10, 10, 'Nintendo Online',  'Family',   '2022-08-01', 7.99,  TRUE),
(11, 11, 'PS Plus',          'Essential','2023-06-01', 9.99,  TRUE),
(12, 12, 'PS Plus',          'Extra',    '2022-03-15', 13.99, TRUE),
(13, 13, 'Game Pass',        'Core',     '2023-09-01', 9.99,  FALSE),
(14, 14, 'PS Plus',          'Premium',  '2021-10-01', 17.99, TRUE),
(15, 15, 'Game Pass',        'Ultimate', '2023-11-01', 16.99, TRUE);

-- ---------------------------------------------------------------------------
-- Table: SUPPORT_TICKETS — Customer support interactions (15 rows)
-- ---------------------------------------------------------------------------
CREATE TABLE SUPPORT_TICKETS (
    TICKET_ID       INTEGER,
    PLAYER_ID       INTEGER,
    CATEGORY        VARCHAR(30),
    PRIORITY        VARCHAR(10),
    CREATED_DATE    DATE,
    RESOLVED_DATE   DATE,
    SATISFACTION    INTEGER
);

INSERT INTO SUPPORT_TICKETS VALUES
(1,  1,  'Account',      'Medium', '2024-01-10', '2024-01-11', 4),
(2,  2,  'Billing',      'High',   '2024-01-12', '2024-01-12', 5),
(3,  3,  'Technical',    'High',   '2024-01-14', '2024-01-16', 3),
(4,  4,  'Account',      'Low',    '2024-01-15', '2024-01-15', 5),
(5,  5,  'Billing',      'Medium', '2024-01-16', '2024-01-17', 4),
(6,  6,  'Technical',    'High',   '2024-01-18', '2024-01-20', 2),
(7,  7,  'Game Issue',   'Medium', '2024-01-19', '2024-01-20', 4),
(8,  8,  'Account',      'Low',    '2024-01-20', '2024-01-20', 5),
(9,  9,  'Billing',      'High',   '2024-01-21', '2024-01-22', 3),
(10, 10, 'Technical',    'Medium', '2024-01-22', '2024-01-24', 4),
(11, 11, 'Game Issue',   'Low',    '2024-01-23', '2024-01-23', 5),
(12, 12, 'Account',      'Medium', '2024-01-24', '2024-01-25', 4),
(13, 1,  'Technical',    'High',   '2024-01-25', '2024-01-27', 3),
(14, 3,  'Billing',      'Medium', '2024-01-26', '2024-01-27', 4),
(15, 5,  'Game Issue',   'Low',    '2024-01-27', '2024-01-27', 5);


-- ============================================================================
-- LAYER 1: Shared Dimension Semantic Views
-- ============================================================================

-- ---------------------------------------------------------------------------
-- SV_PLAYERS: Shared player dimension
-- NOTE: Dimension named PLAYER_ID must match the PK column so that downstream
--       relationships can reference it (constraint: ref-key on imported entity
--       must be both a calculation AND the primary key).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SV_PLAYERS
  TABLES (
    DEMO_DB.GAMING.PLAYERS PRIMARY KEY (PLAYER_ID)
  )
  DIMENSIONS (
    PLAYERS.PLAYER_ID AS PLAYERS.PLAYER_ID COMMENT='Player ID dimension',
    PLAYERS.D_GAMER_TAG AS PLAYERS.GAMER_TAG COMMENT='Gamer tag dimension',
    PLAYERS.D_REGION AS PLAYERS.REGION COMMENT='Player region',
    PLAYERS.D_TIER AS PLAYERS.TIER COMMENT='Player loyalty tier',
    PLAYERS.D_SIGNUP_DATE AS PLAYERS.SIGNUP_DATE COMMENT='Player signup date'
  )
  METRICS (
    PLAYERS.M_PLAYER_COUNT AS COUNT(DISTINCT PLAYERS.PLAYER_ID) COMMENT='Total unique players'
  )
  COMMENT='Shared player dimension — base layer for all domain SVs';

-- ---------------------------------------------------------------------------
-- SV_CONSOLE_CATALOG: Shared product catalog (consoles + games)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SV_CONSOLE_CATALOG
  TABLES (
    DEMO_DB.GAMING.CONSOLES PRIMARY KEY (CONSOLE_ID),
    DEMO_DB.GAMING.GAMES PRIMARY KEY (GAME_ID)
  )
  RELATIONSHIPS (
    GAMES_TO_CONSOLES AS GAMES(CONSOLE_ID) REFERENCES CONSOLES(CONSOLE_ID)
  )
  DIMENSIONS (
    CONSOLES.CONSOLE_ID AS CONSOLES.CONSOLE_ID COMMENT='Console ID dimension',
    CONSOLES.D_CONSOLE_NAME AS CONSOLES.CONSOLE_NAME COMMENT='Console name',
    CONSOLES.D_MANUFACTURER AS CONSOLES.MANUFACTURER COMMENT='Console manufacturer',
    CONSOLES.D_GENERATION AS CONSOLES.GENERATION COMMENT='Console generation',
    CONSOLES.D_RELEASE_YEAR AS CONSOLES.RELEASE_YEAR COMMENT='Console release year',
    GAMES.GAME_ID AS GAMES.GAME_ID COMMENT='Game ID dimension',
    GAMES.D_GAME_TITLE AS GAMES.GAME_TITLE COMMENT='Game title',
    GAMES.D_GENRE AS GAMES.GENRE COMMENT='Game genre',
    GAMES.D_RELEASE_DATE AS GAMES.RELEASE_DATE COMMENT='Game release date'
  )
  METRICS (
    CONSOLES.M_CONSOLE_COUNT AS COUNT(DISTINCT CONSOLES.CONSOLE_ID) COMMENT='Total consoles',
    CONSOLES.M_AVG_PRICE AS AVG(CONSOLES.BASE_PRICE) COMMENT='Average console price',
    GAMES.M_GAME_COUNT AS COUNT(DISTINCT GAMES.GAME_ID) COMMENT='Total games',
    GAMES.M_AVG_RATING AS AVG(GAMES.RATING) COMMENT='Average game rating'
  )
  COMMENT='Shared product catalog — consoles and game titles';


-- ============================================================================
-- LAYER 2: Domain Semantic Views (Import Layer 1 + Local Tables)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- SV_ENGAGEMENT: Player activity & session metrics
-- [Feature 1] IMPORTS clause
-- [Feature 2] All-or-nothing import — gets ALL dims/metrics from both imported SVs
-- [Feature 3] Local tables alongside imports (GAME_SESSIONS is local)
-- [Feature 5] Relationships on imported entities using logical names
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SV_ENGAGEMENT
  IMPORTS (DEMO_DB.GAMING.SV_PLAYERS, DEMO_DB.GAMING.SV_CONSOLE_CATALOG)
  TABLES (
    DEMO_DB.GAMING.GAME_SESSIONS PRIMARY KEY (SESSION_ID)
  )
  RELATIONSHIPS (
    SESSIONS_TO_PLAYERS AS GAME_SESSIONS(PLAYER_ID) REFERENCES PLAYERS(PLAYER_ID),
    SESSIONS_TO_GAMES AS GAME_SESSIONS(GAME_ID) REFERENCES GAMES(GAME_ID)
  )
  DIMENSIONS (
    GAME_SESSIONS.D_SESSION_ID AS GAME_SESSIONS.SESSION_ID COMMENT='Session ID',
    GAME_SESSIONS.D_SESSION_DATE AS GAME_SESSIONS.SESSION_DATE COMMENT='Session date',
    GAME_SESSIONS.D_PLAYER_ID AS GAME_SESSIONS.PLAYER_ID COMMENT='Player FK in session'
  )
  METRICS (
    GAME_SESSIONS.M_TOTAL_SESSIONS AS COUNT(DISTINCT GAME_SESSIONS.SESSION_ID) COMMENT='Total play sessions',
    GAME_SESSIONS.M_TOTAL_PLAY_MINUTES AS SUM(GAME_SESSIONS.DURATION_MINS) COMMENT='Total minutes played',
    GAME_SESSIONS.M_AVG_SESSION_MINUTES AS AVG(GAME_SESSIONS.DURATION_MINS) COMMENT='Average session length in minutes',
    GAME_SESSIONS.M_TOTAL_ACHIEVEMENTS AS SUM(GAME_SESSIONS.ACHIEVEMENTS) COMMENT='Total achievements unlocked'
  )
  COMMENT='Player engagement domain — session activity and play patterns';

-- ---------------------------------------------------------------------------
-- SV_STORE: Revenue & transaction metrics
-- [Feature 1] IMPORTS clause
-- [Feature 3] Local tables alongside imports (PURCHASES + SUBSCRIPTIONS)
-- [Feature 5] Multiple relationships to imported entities
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SV_STORE
  IMPORTS (DEMO_DB.GAMING.SV_PLAYERS, DEMO_DB.GAMING.SV_CONSOLE_CATALOG)
  TABLES (
    DEMO_DB.GAMING.PURCHASES PRIMARY KEY (PURCHASE_ID),
    DEMO_DB.GAMING.SUBSCRIPTIONS PRIMARY KEY (SUBSCRIPTION_ID)
  )
  RELATIONSHIPS (
    PURCHASES_TO_PLAYERS AS PURCHASES(PLAYER_ID) REFERENCES PLAYERS(PLAYER_ID),
    PURCHASES_TO_GAMES AS PURCHASES(GAME_ID) REFERENCES GAMES(GAME_ID),
    PURCHASES_TO_CONSOLES AS PURCHASES(CONSOLE_ID) REFERENCES CONSOLES(CONSOLE_ID),
    SUBSCRIPTIONS_TO_PLAYERS AS SUBSCRIPTIONS(PLAYER_ID) REFERENCES PLAYERS(PLAYER_ID)
  )
  DIMENSIONS (
    PURCHASES.D_PURCHASE_ID AS PURCHASES.PURCHASE_ID COMMENT='Purchase ID',
    PURCHASES.D_PURCHASE_DATE AS PURCHASES.PURCHASE_DATE COMMENT='Purchase date',
    PURCHASES.D_PURCHASE_TYPE AS PURCHASES.PURCHASE_TYPE COMMENT='Digital or Physical',
    SUBSCRIPTIONS.D_SUBSCRIPTION_ID AS SUBSCRIPTIONS.SUBSCRIPTION_ID COMMENT='Subscription ID',
    SUBSCRIPTIONS.D_SERVICE_NAME AS SUBSCRIPTIONS.SERVICE_NAME COMMENT='Service name',
    SUBSCRIPTIONS.D_SUB_TIER AS SUBSCRIPTIONS.TIER COMMENT='Subscription tier',
    SUBSCRIPTIONS.D_IS_ACTIVE AS SUBSCRIPTIONS.IS_ACTIVE COMMENT='Active subscription flag'
  )
  METRICS (
    PURCHASES.M_TOTAL_REVENUE AS SUM(PURCHASES.AMOUNT) COMMENT='Total purchase revenue',
    PURCHASES.M_PURCHASE_COUNT AS COUNT(DISTINCT PURCHASES.PURCHASE_ID) COMMENT='Total purchases',
    PURCHASES.M_AVG_PURCHASE AS AVG(PURCHASES.AMOUNT) COMMENT='Average purchase amount',
    SUBSCRIPTIONS.M_ACTIVE_SUBS AS COUNT_IF(SUBSCRIPTIONS.IS_ACTIVE = TRUE) COMMENT='Active subscriptions',
    SUBSCRIPTIONS.M_MONTHLY_RECURRING AS SUM(IFF(SUBSCRIPTIONS.IS_ACTIVE, SUBSCRIPTIONS.MONTHLY_COST, 0)) COMMENT='Monthly recurring revenue'
  )
  COMMENT='Store domain — purchases, subscriptions, and revenue metrics';

-- ---------------------------------------------------------------------------
-- SV_SUPPORT: Customer support metrics
-- [Feature 1] IMPORTS clause (imports only SV_PLAYERS)
-- [Feature 3] Local table alongside imports
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SV_SUPPORT
  IMPORTS (DEMO_DB.GAMING.SV_PLAYERS)
  TABLES (
    DEMO_DB.GAMING.SUPPORT_TICKETS PRIMARY KEY (TICKET_ID)
  )
  RELATIONSHIPS (
    TICKETS_TO_PLAYERS AS SUPPORT_TICKETS(PLAYER_ID) REFERENCES PLAYERS(PLAYER_ID)
  )
  DIMENSIONS (
    SUPPORT_TICKETS.D_TICKET_ID AS SUPPORT_TICKETS.TICKET_ID COMMENT='Ticket ID',
    SUPPORT_TICKETS.D_CATEGORY AS SUPPORT_TICKETS.CATEGORY COMMENT='Support category',
    SUPPORT_TICKETS.D_PRIORITY AS SUPPORT_TICKETS.PRIORITY COMMENT='Ticket priority',
    SUPPORT_TICKETS.D_CREATED_DATE AS SUPPORT_TICKETS.CREATED_DATE COMMENT='Ticket created date'
  )
  METRICS (
    SUPPORT_TICKETS.M_TICKET_COUNT AS COUNT(DISTINCT SUPPORT_TICKETS.TICKET_ID) COMMENT='Total support tickets',
    SUPPORT_TICKETS.M_AVG_SATISFACTION AS AVG(SUPPORT_TICKETS.SATISFACTION) COMMENT='Average satisfaction score',
    SUPPORT_TICKETS.M_AVG_RESOLUTION_DAYS AS AVG(DATEDIFF('day', SUPPORT_TICKETS.CREATED_DATE, SUPPORT_TICKETS.RESOLVED_DATE)) COMMENT='Average days to resolve'
  )
  COMMENT='Support domain — ticket volume, resolution times, satisfaction';


-- ============================================================================
-- LAYER 3: Executive Dashboard (Transitive Imports)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- SV_EXECUTIVE: Cross-domain composed view
-- [Feature 4] New metric on imported entity (M_SESSIONS_PER_PLAYER on shadow GAME_SESSIONS)
-- [Feature 6] Transitive imports: SV_EXECUTIVE → SV_ENGAGEMENT → SV_PLAYERS + SV_CONSOLE_CATALOG
--
-- NOTE: Cannot import both SV_ENGAGEMENT and SV_STORE because they share
--       SV_PLAYERS as a common ancestor (diamond import not allowed).
--       This view imports SV_ENGAGEMENT only, demonstrating 3-level transitivity.
--
-- NOTE: Metric expressions on imported entities must reference dimension/metric
--       names (calculations), not raw physical columns.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SV_EXECUTIVE
  IMPORTS (DEMO_DB.GAMING.SV_ENGAGEMENT)
  METRICS (
    GAME_SESSIONS.M_SESSIONS_PER_PLAYER AS COUNT(DISTINCT GAME_SESSIONS.D_SESSION_ID) / NULLIF(COUNT(DISTINCT GAME_SESSIONS.D_PLAYER_ID), 0) COMMENT='Average sessions per player (cross-domain metric on imported entity)'
  )
  COMMENT='Executive dashboard — cross-domain KPIs via transitive imports';


-- ============================================================================
-- DEMO QUERIES
-- ============================================================================

-- ---------------------------------------------------------------------------
-- [Feature 15] Query: imported dimension + local metric
-- players.D_REGION is imported from SV_PLAYERS; PURCHASES.M_TOTAL_REVENUE is local
-- ---------------------------------------------------------------------------
SELECT '--- Feature 15: Imported dimension + local metric ---' AS demo;

SELECT *
FROM SEMANTIC_VIEW(
    SV_STORE
    DIMENSIONS PLAYERS.D_REGION
    METRICS PURCHASES.M_TOTAL_REVENUE
);

-- ---------------------------------------------------------------------------
-- [Feature 16] Query: imported metric from composed view
-- M_AVG_SESSION_MINUTES was defined in SV_ENGAGEMENT, accessed via SV_EXECUTIVE
-- ---------------------------------------------------------------------------
SELECT '--- Feature 16: Imported metric from composed view ---' AS demo;

SELECT *
FROM SEMANTIC_VIEW(
    SV_EXECUTIVE
    METRICS GAME_SESSIONS.M_AVG_SESSION_MINUTES
);

-- ---------------------------------------------------------------------------
-- [Feature 17] Query: mix imported + local dimensions
-- PLAYERS.D_TIER is imported; GAME_SESSIONS.D_SESSION_DATE is local
-- ---------------------------------------------------------------------------
SELECT '--- Feature 17: Mix imported + local dimensions ---' AS demo;

SELECT *
FROM SEMANTIC_VIEW(
    SV_ENGAGEMENT
    DIMENSIONS PLAYERS.D_TIER, GAME_SESSIONS.D_SESSION_DATE
    METRICS GAME_SESSIONS.M_TOTAL_SESSIONS
);

-- ---------------------------------------------------------------------------
-- [Feature 4] New metric on imported entity — sessions per player
-- This metric is defined locally in SV_EXECUTIVE on the imported GAME_SESSIONS shadow
-- ---------------------------------------------------------------------------
SELECT '--- Feature 4: Cross-domain metric on imported entity ---' AS demo;

SELECT *
FROM SEMANTIC_VIEW(
    SV_EXECUTIVE
    DIMENSIONS PLAYERS.D_REGION
    METRICS GAME_SESSIONS.M_SESSIONS_PER_PLAYER
);

-- ---------------------------------------------------------------------------
-- [Feature 6] Three-level transitive import
-- SV_EXECUTIVE → SV_ENGAGEMENT → SV_CONSOLE_CATALOG gives access to GAMES dims
-- ---------------------------------------------------------------------------
SELECT '--- Feature 6: Three-level transitive import ---' AS demo;

SELECT *
FROM SEMANTIC_VIEW(
    SV_EXECUTIVE
    DIMENSIONS GAMES.D_GENRE
    METRICS GAME_SESSIONS.M_TOTAL_PLAY_MINUTES
);

-- ---------------------------------------------------------------------------
-- Additional: Query SV_STORE with imported player region + local purchase type
-- ---------------------------------------------------------------------------
SELECT '--- Bonus: Store revenue by region and purchase type ---' AS demo;

SELECT *
FROM SEMANTIC_VIEW(
    SV_STORE
    DIMENSIONS PLAYERS.D_REGION, PURCHASES.D_PURCHASE_TYPE
    METRICS PURCHASES.M_TOTAL_REVENUE
);

-- ---------------------------------------------------------------------------
-- Additional: Support metrics by player region
-- ---------------------------------------------------------------------------
SELECT '--- Bonus: Support tickets by player region ---' AS demo;

SELECT *
FROM SEMANTIC_VIEW(
    SV_SUPPORT
    DIMENSIONS PLAYERS.D_REGION
    METRICS SUPPORT_TICKETS.M_TICKET_COUNT, SUPPORT_TICKETS.M_AVG_SATISFACTION
);


-- ============================================================================
-- INTROSPECTION DEMOS
-- ============================================================================

-- ---------------------------------------------------------------------------
-- [Feature 11] DESCRIBE SEMANTIC VIEW
-- Shows IMPORT rows (with source SV FQN) and shadow TABLE rows for executive
-- ---------------------------------------------------------------------------
SELECT '--- Feature 11: DESCRIBE SEMANTIC VIEW ---' AS demo;

DESCRIBE SEMANTIC VIEW SV_EXECUTIVE;

-- ---------------------------------------------------------------------------
-- [Feature 12] SHOW SEMANTIC VIEWS — imports column with FQN arrays
-- Shows all 6 SVs with their import dependencies
-- ---------------------------------------------------------------------------
SELECT '--- Feature 12: SHOW SEMANTIC VIEWS ---' AS demo;

SHOW SEMANTIC VIEWS IN SCHEMA DEMO_DB.GAMING;

-- ---------------------------------------------------------------------------
-- [Feature 13] GET_DDL — includes IMPORTS clause in output
-- ---------------------------------------------------------------------------
SELECT '--- Feature 13: GET_DDL ---' AS demo;

SELECT GET_DDL('SEMANTIC_VIEW', 'DEMO_DB.GAMING.SV_EXECUTIVE');

-- ---------------------------------------------------------------------------
-- [Feature 9, 10, 14] SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW
-- Shows: imports block, is_imported: true for shadow tables,
--        imported_semantic_models with full transitive chain
-- ---------------------------------------------------------------------------
SELECT '--- Features 9, 10, 14: YAML with imports and shadow tables ---' AS demo;

SELECT SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW('DEMO_DB.GAMING.SV_EXECUTIVE');

-- Also show YAML for a Layer 2 view (mix of local + imported entities)
SELECT '--- YAML for Layer 2 (SV_ENGAGEMENT) showing mix of local + imported ---' AS demo;

SELECT SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW('DEMO_DB.GAMING.SV_ENGAGEMENT');


-- ============================================================================
-- LATE BINDING DEMO
-- [Feature 7] Altering source SV propagates to composed view at runtime
-- ============================================================================

SELECT '--- Feature 7: Late Binding Demo ---' AS demo;

-- Step 1: Add a new dimension to the base SV_PLAYERS via CREATE OR REPLACE
-- (ALTER SEMANTIC VIEW does not support ADD DIMENSION; use CREATE OR REPLACE)
CREATE OR REPLACE SEMANTIC VIEW SV_PLAYERS
  TABLES (
    DEMO_DB.GAMING.PLAYERS PRIMARY KEY (PLAYER_ID)
  )
  DIMENSIONS (
    PLAYERS.PLAYER_ID AS PLAYERS.PLAYER_ID COMMENT='Player ID dimension',
    PLAYERS.D_GAMER_TAG AS PLAYERS.GAMER_TAG COMMENT='Gamer tag dimension',
    PLAYERS.D_REGION AS PLAYERS.REGION COMMENT='Player region',
    PLAYERS.D_TIER AS PLAYERS.TIER COMMENT='Player loyalty tier',
    PLAYERS.D_SIGNUP_DATE AS PLAYERS.SIGNUP_DATE COMMENT='Player signup date',
    PLAYERS.D_EMAIL_DOMAIN AS SPLIT_PART(PLAYERS.EMAIL, '@', 2) COMMENT='Email domain — added for late binding demo'
  )
  METRICS (
    PLAYERS.M_PLAYER_COUNT AS COUNT(DISTINCT PLAYERS.PLAYER_ID) COMMENT='Total unique players'
  )
  COMMENT='Shared player dimension — base layer for all domain SVs';

-- Step 2: Immediately query the NEW dimension through SV_EXECUTIVE (3 layers deep!)
-- No need to recreate SV_ENGAGEMENT or SV_EXECUTIVE
SELECT *
FROM SEMANTIC_VIEW(
    SV_EXECUTIVE
    DIMENSIONS PLAYERS.D_EMAIL_DOMAIN
    METRICS GAME_SESSIONS.M_TOTAL_SESSIONS
);

-- Step 3: Verify new dimension appears in DESCRIBE (propagated through 3 layers)
DESCRIBE SEMANTIC VIEW SV_EXECUTIVE;


-- ============================================================================
-- PRIVILEGE RESOLUTION DEMO
-- [Feature 8] REFERENCES + SELECT on SV grants access; base tables resolve
--             under the SV owner's privileges
-- ============================================================================

SELECT '--- Feature 8: Privilege Resolution Demo ---' AS demo;

-- Create a restricted analyst role
CREATE ROLE IF NOT EXISTS GAMING_ANALYST;
GRANT USAGE ON DATABASE DEMO_DB TO ROLE GAMING_ANALYST;
GRANT USAGE ON SCHEMA DEMO_DB.GAMING TO ROLE GAMING_ANALYST;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE GAMING_ANALYST;

-- Grant ONLY REFERENCES + SELECT on the composed semantic view (NOT on base tables)
GRANT REFERENCES ON SEMANTIC VIEW DEMO_DB.GAMING.SV_EXECUTIVE TO ROLE GAMING_ANALYST;
GRANT SELECT ON SEMANTIC VIEW DEMO_DB.GAMING.SV_EXECUTIVE TO ROLE GAMING_ANALYST;

-- Grant role to current user for testing
GRANT ROLE GAMING_ANALYST TO ROLE ACCOUNTADMIN;

-- Switch to analyst role and query the composed view
-- Base table access resolves under SV owner (ACCOUNTADMIN) privileges
USE ROLE GAMING_ANALYST;

SELECT *
FROM SEMANTIC_VIEW(
    DEMO_DB.GAMING.SV_EXECUTIVE
    DIMENSIONS PLAYERS.D_REGION
    METRICS GAME_SESSIONS.M_TOTAL_SESSIONS
);

-- Analyst can also see metadata
SHOW SEMANTIC VIEWS IN SCHEMA DEMO_DB.GAMING;

-- Switch back
USE ROLE ACCOUNTADMIN;


-- ============================================================================
-- CLEANUP (optional — comment out to keep demo objects)
-- ============================================================================

-- DROP ROLE IF EXISTS GAMING_ANALYST;
-- DROP SEMANTIC VIEW IF EXISTS SV_EXECUTIVE;
-- DROP SEMANTIC VIEW IF EXISTS SV_ENGAGEMENT;
-- DROP SEMANTIC VIEW IF EXISTS SV_STORE;
-- DROP SEMANTIC VIEW IF EXISTS SV_SUPPORT;
-- DROP SEMANTIC VIEW IF EXISTS SV_PLAYERS;
-- DROP SEMANTIC VIEW IF EXISTS SV_CONSOLE_CATALOG;
-- DROP TABLE IF EXISTS SUPPORT_TICKETS;
-- DROP TABLE IF EXISTS SUBSCRIPTIONS;
-- DROP TABLE IF EXISTS PURCHASES;
-- DROP TABLE IF EXISTS GAME_SESSIONS;
-- DROP TABLE IF EXISTS GAMES;
-- DROP TABLE IF EXISTS CONSOLES;
-- DROP TABLE IF EXISTS PLAYERS;
-- DROP SCHEMA IF EXISTS DEMO_DB.GAMING;


-- ============================================================================
-- SUMMARY
-- ============================================================================
/*
 * All 17 features from the composable semantic views specification demonstrated:
 *
 *  ✓ Feature 1:  IMPORTS clause (all Layer 2 + Layer 3 SVs)
 *  ✓ Feature 2:  All-or-nothing import (SV_ENGAGEMENT imports 2 full SVs)
 *  ✓ Feature 3:  Local tables alongside imports (Layer 2 SVs)
 *  ✓ Feature 4:  New metrics on imported entities (SV_EXECUTIVE.M_SESSIONS_PER_PLAYER)
 *  ✓ Feature 5:  Relationships using logical names (SESSIONS_TO_PLAYERS, etc.)
 *  ✓ Feature 6:  Transitive imports (SV_EXECUTIVE → SV_ENGAGEMENT → SV_PLAYERS/CATALOG)
 *  ✓ Feature 7:  Late binding (CREATE OR REPLACE SV_PLAYERS, query through SV_EXECUTIVE)
 *  ✓ Feature 8:  Privilege resolution (GAMING_ANALYST role)
 *  ✓ Feature 9:  YAML imports block (SYSTEM$READ_YAML output)
 *  ✓ Feature 10: is_imported: true shadow tables (YAML output)
 *  ✓ Feature 11: DESCRIBE SEMANTIC VIEW (metadata rows)
 *  ✓ Feature 12: SHOW SEMANTIC VIEWS imports column
 *  ✓ Feature 13: GET_DDL with IMPORTS clause
 *  ✓ Feature 14: SYSTEM$READ_YAML_FROM_SEMANTIC_VIEW (imported_semantic_models)
 *  ✓ Feature 15: Query: imported dim + local metric
 *  ✓ Feature 16: Query: imported metric from composed view
 *  ✓ Feature 17: Query: mix imported + local dimensions
 *
 * Architecture:
 *   Layer 1:  SV_PLAYERS, SV_CONSOLE_CATALOG (shared dimensions, no imports)
 *   Layer 2:  SV_ENGAGEMENT (imports both L1), SV_STORE (imports both L1), SV_SUPPORT (imports SV_PLAYERS)
 *   Layer 3:  SV_EXECUTIVE (imports SV_ENGAGEMENT → transitive access to all L1 entities)
 *
 * Key constraints discovered:
 *   - Diamond imports prohibited (two paths to same ancestor SV)
 *   - Relationship ref-keys on imported entities must be calculation names (not physical columns)
 *   - Dimension name for PK columns should match the PK column name exactly
 *   - Metrics on imported entities can only reference imported dimensions/metrics
 *   - ALTER SEMANTIC VIEW does not support ADD DIMENSION (use CREATE OR REPLACE)
 *
 * Total physical tables: 7
 * Total semantic views: 6
 * Import depth: 3 levels (Executive → Engagement → Players/Catalog)
 */

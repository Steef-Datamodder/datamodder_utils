# profile

Snowflake stored procedure die een schema automatisch scant op persoonsgegevens (PII) op basis van configureerbare regex-regels.

---

## Vereiste objecten

Voordat de procedure werkt moeten de volgende tabellen bestaan in `UTILS_DATABASE.UTILS_SCHEMA` (default: de database/het schema waar de procedure in staat):

### PII_REGEX_RULES

Configuratietabel met detectieregels. Voeg hier rijen toe om nieuwe PII-typen te ondersteunen — geen codewijziging nodig.

```sql
CREATE TABLE PII_REGEX_RULES (
    pii_type              TEXT,     -- bijv. 'BSN', 'EMAIL', 'NAAM'
    rule_name             TEXT,     -- unieke naam binnen pii_type
    column_name_regex     TEXT,     -- regex op kolomnaam (null = niet checken)
    value_regex           TEXT,     -- regex op kolominhoud (null = niet checken)
    data_type_regex       TEXT,     -- filter op Snowflake datatype, bijv. 'TEXT|VARCHAR' (null = alle typen)
    confidence_name_match FLOAT,    -- score (0.0–1.0) bij treffer op kolomnaam
    confidence_value_match FLOAT,   -- score (0.0–1.0) bij treffer op kolomwaarden
    suggested_action      TEXT,     -- bijv. 'maskeren', 'verwijderen'
    is_active             BOOLEAN   -- false = regel overgeslagen
);
```

**Detectielogica per regel:**
- Als `column_name_regex` matcht → naamtreffer
- Als `value_regex` matcht op ≥ `MATCH_THRESHOLD` van de samples → waardetreffer
- Als `data_type_regex` niet matcht → kolom overgeslagen voor deze regel
- Een kolom wordt als bevinding geregistreerd zodra naamtreffer **of** waardetreffer geldt

**Confidence-berekening:**
`min(confidence_name_match + confidence_value_match, 1.0)` — beide signalen tellen op. Als alleen de naam matcht: `confidence_name_match`. Als alleen de waarden matchen: `confidence_value_match`. Als beide matchen: som, geclipped op 1.0.

**Voorbeeldrijen:**

| pii_type | rule_name | column_name_regex | value_regex | data_type_regex | confidence_name_match | confidence_value_match | suggested_action | is_active |
|---|---|---|---|---|---|---|---|---|
| BSN | bsn_naam | `(^|_)(bsn|sofi)(\_|$)` | null | `TEXT\|VARCHAR` | 0.8 | null | maskeren | true |
| BSN | bsn_waarde | null | `^\d{9}$` | `TEXT\|VARCHAR\|NUMBER` | null | 0.7 | maskeren | true |
| EMAIL | email_naam | `email` | null | null | 0.9 | null | maskeren | true |
| EMAIL | email_waarde | null | `^[^@]+@[^@]+\.[^@]+$` | `TEXT\|VARCHAR` | null | 0.85 | maskeren | true |
| NAAM | naam_kolom | `(^|_)(naam\|name\|voornaam\|achternaam)(\_\|$)` | null | null | 0.6 | null | pseudonimiseren | true |

### PII_SCAN_RESULTS

Resultaattabel — wordt aangemaakt vóór de eerste aanroep.

```sql
CREATE TABLE PII_SCAN_RESULTS (
    scan_id              TEXT,
    scanned_at           TIMESTAMP_TZ,
    database_name        TEXT,
    schema_name          TEXT,
    table_name           TEXT,
    column_name          TEXT,
    data_type            TEXT,
    pii_type             TEXT,
    rule_name            TEXT,
    confidence           FLOAT,
    detection_reason     TEXT,
    matched_sample_count NUMBER,
    sample_size          NUMBER,
    suggested_action     TEXT
);
```

---

## Aanroepen

```sql
-- Minimaal
CALL DATAMODDER_UTILS.PROFILE_PII('MY_DATABASE', 'MY_SCHEMA', 1000);

-- Met drempel en afwijkend utils-schema
CALL DATAMODDER_UTILS.PROFILE_PII(
    'MY_DATABASE',
    'MY_SCHEMA',
    500,
    0.05,                  -- match_threshold: 5% van samples moet matchen
    'UTILS_DB',
    'DATAMODDER'
);
```

---

## Parameters

| Parameter | Type | Default | Omschrijving |
|---|---|---|---|
| `DATABASE_NAME` | string | — | Database om te scannen (verplicht) |
| `SCHEMA_NAME` | string | — | Schema om te scannen (verplicht) |
| `SAMPLE_ROWS` | number | — | Aantal rijen per kolom voor de waardescan (0 → 1000) |
| `MATCH_THRESHOLD` | float | `0.1` | Minimaal aandeel van samples dat de regex moet matchen (0.0–1.0) |
| `UTILS_DATABASE` | string | huidige database | Database met `PII_REGEX_RULES` en `PII_SCAN_RESULTS` |
| `UTILS_SCHEMA` | string | huidig schema | Schema met `PII_REGEX_RULES` en `PII_SCAN_RESULTS` |

---

## Returnwaarde

De procedure retourneert een `VARIANT` met een samenvatting van de scan:

```json
{
    "scan_id":         "a1b2c3d4-...",
    "database_name":   "MY_DATABASE",
    "schema_name":     "MY_SCHEMA",
    "sample_rows":     1000,
    "match_threshold": 0.1,
    "scanned_columns": 142,
    "findings":        7
}
```

Alle details staan in `PII_SCAN_RESULTS` gefilterd op `scan_id`.

---

## Hoe werkt het

### Stap 1 — kandidatenlijst

Eén query cross-joint `information_schema.columns` met `PII_REGEX_RULES`. Snowflake evalueert direct:
- **typefilter** (`data_type_regex`): kolommen waarvan het datatype niet matcht worden uitgefilterd
- **naamcheck** (`column_name_regex`): uitkomst wordt als `name_matched` kolom meegestuurd

Python ontvangt alleen de (kolom, regel)-combinaties die het typefilter passeerden. Dit vervangt N×M afzonderlijke round trips door één query.

Alleen base tables worden gescand — views worden overgeslagen.

### Stap 2 — waardescans

Voor elke kandidaat met een `value_regex` wordt een steekproef getrokken:

```sql
SELECT count(*) AS sample_size
     , count_if(regexp_like(to_varchar(<kolom>), <regex>, 'i')) AS matched_count
  FROM (
      SELECT <kolom> FROM <tabel> WHERE <kolom> IS NOT NULL LIMIT <sample_rows>
  )
```

`match_ratio = matched_count / sample_size`. Als `match_ratio >= MATCH_THRESHOLD` → waardetreffer.

> **Let op:** `LIMIT` trekt de eerste N rijen in de opslag­volgorde, niet een statistische steekproef. Gesorteerde of gesegmenteerde tabellen kunnen een vertekend beeld geven. Gebruik een hogere `SAMPLE_ROWS` voor meer betrouwbaarheid, of pas de tabel aan zodat de data gemengder is.

### Stap 3 — resultaten opslaan

Bevindingen worden één voor één geïnsert in `PII_SCAN_RESULTS`. Kolommen zonder treffer worden niet opgeslagen.

---

## Resultaten opvragen

```sql
-- Laatste scan
SELECT *
  FROM DATAMODDER_UTILS.PII_SCAN_RESULTS
 WHERE scan_id = (SELECT max(scan_id) FROM DATAMODDER_UTILS.PII_SCAN_RESULTS)
 ORDER BY confidence DESC, table_name, column_name;

-- Alle bevindingen met hoge confidence
SELECT table_name, column_name, pii_type, confidence, suggested_action
  FROM DATAMODDER_UTILS.PII_SCAN_RESULTS
 WHERE confidence >= 0.8
 ORDER BY confidence DESC;

-- Per PII-type samenvatten
SELECT pii_type, count(*) AS aantal_kolommen
  FROM DATAMODDER_UTILS.PII_SCAN_RESULTS
 WHERE scan_id = '<scan_id>'
 GROUP BY pii_type
 ORDER BY aantal_kolommen DESC;
```

---

## Tips

- Zet `MATCH_THRESHOLD` lager (bijv. `0.02`) voor gevoelige scans waarbij je liever te veel dan te weinig rapporteert.
- Zet `MATCH_THRESHOLD` hoger (bijv. `0.5`) als je alleen kolommen wilt melden waarvan de meerderheid PII is.
- Schakel regels tijdelijk uit via `is_active = false` in `PII_REGEX_RULES` zonder ze te verwijderen.
- Scan dezelfde tabel meerdere keren met verschillende drempels en vergelijk via `scan_id`.

# anonymizer

Snowflake stored procedure that anonymizes personal data and other sensitive columns for use in test environments. The original data distribution is preserved as closely as possible to keep test data realistic.

---

## Deployment

Run once, in order:

1. Run `setup.sql` as ACCOUNTADMIN — creates the database, role, and `datamodder` schema.
2. Open `create_anonymize_sp.sql`, set `MY_DATABASE` and `MY_WAREHOUSE` at the top, and run it in DBeaver or the Snowflake UI.

---

## Calling the procedure

```sql
call datamodder.anonymize(
    'myschema.mytable',   -- fully qualified table name (database optional if USE DATABASE is set)
    'id',                 -- primary key column
    parse_json('[
        { "column": "naam",  "method": "shuffle_name" },
        { "column": "email", "method": "random_string", "pattern": "aaaa##@aaaa.nl" }
    ]')
);
```

---

## Methods

### `shuffle`

Redistributes existing values randomly within the column. The set of values stays the same — only the assignment per row changes.

**Single column:**
```json
{ "column": "voornaam", "method": "shuffle" }
```

| id | voornaam_before | voornaam_after |
|----|----------------|----------------|
| 1  | Jan            | Maria          |
| 2  | Maria          | Piet           |
| 3  | Piet           | Jan            |

**Group of columns** — values move as a unit, keeping address fields together:
```json
{ "column": ["straat", "postcode", "woonplaats"], "method": "shuffle" }
```

| id | straat_before | postcode_before | straat_after | postcode_after |
|----|--------------|-----------------|--------------|----------------|
| 1  | Kerkstraat   | 1234 AB         | Molenweg     | 3456 CD        |
| 2  | Hoofdstraat  | 2345 BC         | Kerkstraat   | 1234 AB        |
| 3  | Molenweg     | 3456 CD         | Hoofdstraat  | 2345 BC        |

---

### `shift_housenumber`

Shifts the numeric part of a house number by ±2 or ±4 (20% chance each), or leaves it unchanged (20% chance). Any suffix is preserved.

```json
{ "column": "huisnummer", "method": "shift_housenumber" }
```

| huisnummer_before | huisnummer_after |
|-------------------|-----------------|
| 12                | 14              |
| 34B               | 32B             |
| 3 bis             | 7 bis           |
| 100               | 100             |
| 1                 | 3               |

> House numbers never go below 1.

---

### `random_string`

Generates a random string based on a pattern.

| Character | Meaning |
|-----------|---------|
| `A`       | random uppercase letter (A–Z) |
| `a`       | random lowercase letter (a–z) |
| `#`       | random digit (0–9) |
| other     | literal character |

```json
{ "column": "telefoon", "method": "random_string", "pattern": "##-########" }
{ "column": "postcode", "method": "random_string", "pattern": "#### AA" }
{ "column": "code",     "method": "random_string", "pattern": "AA##-####" }
```

| pattern       | example output |
|---------------|---------------|
| `##-########` | `06-47291836` |
| `#### AA`     | `2847 KJ`     |
| `AA##-####`   | `BF39-7214`   |

---

### `random_lookup`

Fills each row with a random value drawn from a specified column in another table.

**`uniform: true`** (default) — each distinct value has equal probability:
```json
{
    "column": "categorie",
    "method": "random_lookup",
    "source": "datamodder.abc",
    "source_column": "xyz",
    "uniform": true
}
```

**`uniform: false`** — probability proportional to how often a value appears in the source (duplicates count):
```json
{
    "column": "segment",
    "method": "random_lookup",
    "source": "datamodder.abc",
    "source_column": "xyz",
    "uniform": false
}
```

| categorie_before | categorie_after |
|------------------|----------------|
| null             | mango          |
| null             | appel          |
| null             | banaan         |

---

### `shuffle_name`

Shuffles full name strings by splitting each name into a first name part and a last name part, shuffling both independently, then recombining. Infixes (tussenvoegsels) stay attached to the last name they belong to.

```json
{ "column": "naam", "method": "shuffle_name" }
```

**Example output:**

| naam_before | naam_after |
|-------------|------------|
| Jan de Vries | Griet Smit |
| Maria Bakker | P.J. van den Berg |
| P.J. van den Berg | Youssef de Vries |
| Pieter Jan van Boven | Pieter Jan el Amrani |
| Youssef el Amrani | Maria van Boven |

> Voornamen and last name parts are shuffled within separate pools, independently of each other. It is therefore possible for a Dutch voornaam to end up with an Arabic infix — this is intentional, as the goal is anonymization, not name plausibility.

#### Name parsing rules

Names are split into a first name part and a last name part before shuffling. The following rules apply, in order:

| Situation | Example | Result |
|-----------|---------|--------|
| Two words, no infix | `Anna Smit` | voornaam: `Anna`, achternaam: `Smit` |
| Infix between words | `Jan de Vries` | voornaam: `Jan`, achternaam: `de Vries` |
| Multi-word infix | `Jan van den Berg` | voornaam: `Jan`, achternaam: `van den Berg` |
| Multiple voornamen before infix | `Pieter Jan van Boven` | voornaam: `Pieter Jan`, achternaam: `van Boven` |
| No infix, 3+ words | `John Michael Jordan` | voornaam: `John`, achternaam: `Jordan` (middle discarded) |
| Hyphenated name | `Jan-Pieter van den Berg` | voornaam: `Jan-Pieter`, achternaam: `van den Berg` |
| Initial with dot | `J. de Vries` | voornaam: `J.`, achternaam: `de Vries` |
| Initial without dot | `J de Vries` | voornaam: `J.` (dot added), achternaam: `de Vries` |
| Apostrophe in word | `Patrick O'Brien` | voornaam: `Patrick`, achternaam: `O'Brien` |
| Non-Dutch infix | `Youssef el Amrani` | voornaam: `Youssef`, achternaam: `el Amrani` |

**Casing:** names are not normalized — the original casing from the source data is preserved.

**Non-Western names:** supported if they follow Western naming order (first name first). East Asian naming order (family name first) is out of scope.

#### Infix list

Infixes are matched longest-first to avoid partial matches (e.g. `van den` is tried before `van`).

| Language group | Infixes |
|----------------|---------|
| Dutch | `van den`, `van der`, `van de`, `van het`, `van op`, `in den`, `in de`, `in het`, `op den`, `op de`, `op het`, `van`, `de`, `den`, `der`, `het`, `in`, `op`, `te`, `ter`, `ten`, `bij`, `over`, `onder`, `voor`, `aan`, `uit`, `tot`, `d'` |
| German / Austrian | `von und zu`, `von`, `zu` |
| French / Belgian | `de la`, `de los`, `de las`, `du`, `des`, `le`, `la`, `l'` |
| Italian / Spanish | `della`, `degli`, `delle`, `dalla`, `dal`, `del`, `di` |
| Arabic / Berber | `bint`, `ould`, `bou`, `bin`, `ben`, `el`, `al`, `ou` |
| Irish / Scottish | `mac`, `mc`, `o'`, `m'` |
| Scandinavian | `af` |

---

### `shuffle_phone`

Shuffles phone numbers by redistributing the prefix (before the dash) and suffix (after the dash) independently, but only within groups of equal length.

```json
{ "column": "telefoon", "method": "shuffle_phone" }
```

| telefoon_before | telefoon_after |
|----------------|----------------|
| 06-12345678    | 06-56789012    |
| 06-23456789    | 06-12345678    |
| 085-1234567    | 088-2345678    |
| 088-2345678    | 085-1234567    |
| 0800-12345     | 0900-54321     |
| 0900-54321     | 0800-12345     |

> `06` only swaps with other 2-digit prefixes. `085`/`088` swap with each other as 3-digit prefixes. Both prefix and suffix length are always preserved, preventing invalid numbers from being generated.

---

## Method order

Columns in the JSON array are processed in order. This makes it possible to first shuffle and then apply a second method to the same column:

```json
[
    { "column": ["straat", "postcode", "huisnummer"], "method": "shuffle" },
    { "column": "huisnummer", "method": "shift_housenumber" }
]
```

Here `huisnummer` is first shuffled as part of the address group, then shifted independently.

---

## Testing

Open `test_anonymize_sp.sql` in DBeaver, set `MY_DATABASE` and `MY_WAREHOUSE` at the top, and run the entire script. It:

1. Recreates the lookup table `datamodder.abc` (fruit)
2. Recreates the test table `datamodder.test_anonymize` with 10 rows
3. Saves the original values to a temporary table
4. Calls the procedure with all methods at once
5. Shows a side-by-side comparison of before and after for every column

The script is fully restartable — each run starts from a clean slate.

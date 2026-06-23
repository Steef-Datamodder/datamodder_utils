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

Names are split into a first name part and a last name part before shuffling. The rules below apply in order.

---

##### Rule 1 — Two-part name

If the name consists of exactly two words with no known infix, the first word is the first name and the second is the last name.

    Jan Smit          →  voornaam: Jan          achternaam: Smit
    Anna Berg         →  voornaam: Anna         achternaam: Berg

---

##### Rule 2 — Single infix in the middle

If a known infix appears between two words, the word before it is the first name and the word after it is the last name. The infix stays with the last name.

    Jan de Vries      →  voornaam: Jan          achternaam: de Vries
    Maria van Dijk    →  voornaam: Maria        achternaam: van Dijk
    Ali el Bouali     →  voornaam: Ali          achternaam: el Bouali

---

##### Rule 3 — Multiple first names or multiple infix words

Everything before the first infix is treated as the first name (even if it contains multiple words). Everything from the infix onward is the last name part.

    Pieter Jan van Boven        →  voornaam: Pieter Jan       achternaam: van Boven
    Petra van Lippe Bisterveld  →  voornaam: Petra            achternaam: van Lippe Bisterveld
    Jan Willem van den Berg     →  voornaam: Jan Willem       achternaam: van den Berg

Note: multi-word infixes (`van den`, `van der`, `van 't`, etc.) are matched as a unit against the infix list.

---

##### Rule 4 — Hyphens

Hyphens indicate a compound first name or compound last name. They are treated as a single token — no splitting occurs at the hyphen.

    Jan-Pieter Boer             →  voornaam: Jan-Pieter       achternaam: Boer
    Peter Lippe-Bisterveld      →  voornaam: Peter            achternaam: Lippe-Bisterveld
    Jan-Pieter van den Berg     →  voornaam: Jan-Pieter       achternaam: van den Berg

---

##### Rule 5 — No match found

If no infix is detected and the name has more than two words, treat the first word as the first name and the last word as the last name. Any words in between are discarded.

    John Michael Jordan         →  voornaam: John             achternaam: Jordan
    Anna Louise Marie Smit      →  voornaam: Anna             achternaam: Smit

---

##### Rule 6 — Apostrophes

Apostrophes within a word are treated as part of that word, not as a separator.

    Patrick O'Brien             →  voornaam: Patrick          achternaam: O'Brien
    Jan 't Hart                 →  voornaam: Jan              achternaam: 't Hart

The infix `'t` (with apostrophe) must be in the infix list to be recognized.

---

##### Casing

Input names are normalized before parsing: the first letter of each word is uppercased, the rest lowercased. Infixes (`van`, `de`, etc.) are an exception — these are always kept fully lowercase.

    JAN DE VRIES                →  Jan de Vries
    maria bakker                →  Maria Bakker
    TRUUS VAN DEN BERG          →  Truus van den Berg

---

##### Initials

Initials are always treated as the first name, never as a last name or infix. A single uppercase letter (with or without a dot) is recognized as an initial.

If initials appear without dots, they are converted: each letter becomes uppercase followed by a dot.

    J. de Vries                 →  voornaam: J.               achternaam: de Vries
    J de Vries                  →  voornaam: J.               achternaam: de Vries
    JP van Dijk                 →  voornaam: J.P.             achternaam: van Dijk
    J.P. van Dijk               →  voornaam: J.P.             achternaam: van Dijk

Multiple initials before a full first name are grouped with the first name:

    J.P. Jan van Dijk           →  voornaam: J.P. Jan         achternaam: van Dijk

---

##### Non-Western names

Names from non-Western origin are supported, provided they follow Western naming order (first name first, last name last). No special handling for name formats where the family name comes first (e.g. East Asian conventions) — those are out of scope.

---

#### Infix list

Infixes are matched longest-first to avoid partial matches (e.g. `van den` is tried before `van`).

##### Dutch
    van de, van den, van der, van het, van 't, van op
    in de, in den, in het, in 't
    op de, op den, op het, op 't
    van
    de, den, der
    het, 't
    in, op, te, ter, ten
    bij, over, onder, voor, aan, uit, tot
    d'

##### German / Austrian
    von, zu, von und zu, van (also Dutch)

##### French / Belgian
    de, de la, de los, de las, du, des, le, la, l'

##### Italian / Spanish
    di, del, della, degli, delle, dal, dalla
    de, del, de la, de los, de las

##### Arabic / Berber / North African
    el, al, ben, bin, bou, bint, ait, ould, ou

##### Irish / Scottish
    o', mac, mc, m'

##### Other
    af (Scandinavian)
    of (Scottish clan names)

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

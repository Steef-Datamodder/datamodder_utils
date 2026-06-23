# Name parsing decision tree

This document describes how a full name string should be split into a first name part and a last name part (including any infix) for anonymization purposes.

The goal is to shuffle first names and last names independently, while keeping infixes attached to the last name they belong to.

---

## Rules

### Rule 1 — Two-part name
If the name consists of exactly two words with no known infix, the first word is the first name and the second is the last name.

    Jan Smit          →  voornaam: Jan          achternaam: Smit
    Anna Berg         →  voornaam: Anna         achternaam: Berg

---

### Rule 2 — Single infix in the middle
If a known infix appears between two words, the word before it is the first name and the word after it is the last name. The infix stays with the last name.

    Jan de Vries      →  voornaam: Jan          achternaam: de Vries
    Maria van Dijk    →  voornaam: Maria        achternaam: van Dijk
    Ali el Bouali     →  voornaam: Ali          achternaam: el Bouali

---

### Rule 3 — Multiple first names or multiple infix words
Everything before the first infix is treated as the first name (even if it contains multiple words). Everything from the infix onward is the last name part.

    Pieter Jan van Boven        →  voornaam: Pieter Jan       achternaam: van Boven
    Petra van Lippe Bisterveld  →  voornaam: Petra            achternaam: van Lippe Bisterveld
    Jan Willem van den Berg     →  voornaam: Jan Willem       achternaam: van den Berg

Note: multi-word infixes (van den, van der, van 't, etc.) are matched as a unit against the infix list.

---

### Rule 4 — Hyphens
Hyphens indicate a compound first name or compound last name. They are treated as a single token — no splitting occurs at the hyphen.

    Jan-Pieter Boer             →  voornaam: Jan-Pieter       achternaam: Boer
    Peter Lippe-Bisterveld      →  voornaam: Peter            achternaam: Lippe-Bisterveld
    Jan-Pieter van den Berg     →  voornaam: Jan-Pieter       achternaam: van den Berg

---

### Rule 5 — No match found
If no infix is detected and the name has more than two words, treat the first word as the first name and the last word as the last name. Any words in between are discarded.

    John Michael Jordan         →  voornaam: John             achternaam: Jordan
    Anna Louise Marie Smit      →  voornaam: Anna             achternaam: Smit

---

### Rule 6 — Apostrophes
Apostrophes within a word are treated as part of that word, not as a separator.

    Patrick O'Brien             →  voornaam: Patrick          achternaam: O'Brien
    Jan 't Hart                 →  voornaam: Jan              achternaam: 't Hart

The infix `'t` (with apostrophe) must be in the infix list to be recognized.

---

## Infix list

Match longest first to avoid partial matches (e.g. match "van den" before "van").

### Dutch
    van de, van den, van der, van het, van 't, van op
    in de, in den, in het, in 't
    op de, op den, op het, op 't
    van
    de, den, der
    het, 't
    in, op, te, ter, ten
    bij, over, onder, voor, aan, uit, tot
    d'

### German / Austrian
    von, zu, von und zu, van (also Dutch)

### French / Belgian
    de, de la, de los, de las, du, des, le, la, l'

### Italian / Spanish
    di, del, della, degli, delle, dal, dalla
    de, del, de la, de los, de las

### Arabic / Berber / North African
    el, al, ben, bin, bou, bint, ait, ould, ou

### Irish / Scottish
    o', mac, mc, m'

### Other
    af (Scandinavian)
    of (Scottish clan names)

---

## Additional rules

### Casing
Input names are normalized before parsing: the first letter of each word is uppercased, the rest lowercased. Infixes (van, de, etc.) are an exception — these are always kept fully lowercase.

    JAN DE VRIES                →  Jan de Vries
    maria bakker                →  Maria Bakker
    TRUUS VAN DEN BERG          →  Truus van den Berg

### Initials
Initials are always treated as the first name, never as a last name or infix. A single uppercase letter (with or without a dot) is recognized as an initial.

If initials appear without dots, they are converted: each letter becomes uppercase followed by a dot.

    J. de Vries                 →  voornaam: J.               achternaam: de Vries
    J de Vries                  →  voornaam: J.               achternaam: de Vries
    JP van Dijk                 →  voornaam: J.P.             achternaam: van Dijk
    J.P. van Dijk               →  voornaam: J.P.             achternaam: van Dijk

Multiple initials before a full first name are grouped with the first name:

    J.P. Jan van Dijk           →  voornaam: J.P. Jan         achternaam: van Dijk

### Input format
Input is a full name in a single text field. No structural guarantees — the parser applies the rules above to determine the split.

### Non-Western names
Names from non-Western origin are supported, provided they follow Western naming order (first name first, last name last). No special handling for name formats where the family name comes first (e.g. East Asian conventions) — those are out of scope.

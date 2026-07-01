# dbt Sources Generator

Streamlit-app om automatisch dbt-bronbestanden te genereren vanuit Snowflake-metadata.

Starten:

```bash
cd streamlit/generate_sources
pip install -r requirements.txt
streamlit run app.py
```

---

## Verbinding

In de linkerbalk:

| Veld | Toelichting |
|---|---|
| Account | Snowflake account identifier, bijv. `xy12345.eu-west-1` |
| User | Snowflake gebruikersnaam |
| Password | Wachtwoord |

Account en gebruikersnaam worden opgeslagen in `~/.streamlit_sources.json`. Het wachtwoord wordt opgeslagen in de credential store van het besturingssysteem (Windows Credential Manager / macOS Keychain) en wordt bij de volgende keer opstarten automatisch ingevuld.

Na verbinding verschijnen dropdowns voor **Warehouse** en **Role**, gevuld met de warehouses en rollen die beschikbaar zijn voor de ingelogde gebruiker. Wijzigen hiervan heeft direct effect op de sessie — de metadata-cache wordt gewist zodat de nieuwe context wordt gebruikt.

---

## Database en schema's

Na verbinding wordt automatisch de database met de meeste schema's geselecteerd (systeemdatabases zoals `SNOWFLAKE` en `SNOWFLAKE_SAMPLE_DATA` worden overgeslagen). Alle schema's binnen de geselecteerde database zijn standaard aangevinkt. Bij het wisselen van database worden alle schema's van de nieuwe database opnieuw volledig geselecteerd.

---

## Output

Vier opties via checkboxes in de linkerbalk:

| Optie | Beschrijving | Bestandspad |
|---|---|---|
| **sources.yml — Per schema** | Één bronbestand per schema | `models/staging/sources/{schema}.yml` |
| **sources.yml — Gecombineerd** | Alle schema's in één bestand | `models/staging/sources/sources.yml` |
| **Staging models** | Per tabel een `select * from {{ source(...) }}` | `models/staging/{schema}/{table}.sql` |
| **dbt_project.yml snippet** | Fragment om te plakken onder `models:` | Alleen weergegeven, niet weggeschreven |

---

## Bestanden schrijven

Geef het pad naar het dbt-project op in het veld **dbt project path** (of gebruik de Browse-knop voor een mapkiezer). Klik daarna op **Write files** om de geselecteerde outputs direct naar de juiste mappen te schrijven. Het pad wordt opgeslagen in `~/.streamlit_sources.json`.

Het dbt_project.yml-snippet wordt niet weggeschreven — dit is een fragment om handmatig te plakken onder `models:` in `dbt_project.yml`.

---

## Afhankelijkheden

`requirements.txt`:

```
streamlit>=1.35
snowflake-connector-python>=3.10
keyring>=25.0
```

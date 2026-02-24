# Locales Skill

Regenerate i18n translations for a project using the i18n-locale-gen toolkit.

## Usage

```
/locales <service|all>
```

## Arguments

- `service` - The service directory name (e.g., `app`, `www`) OR `all` to regenerate for all services

## Examples

```
/locales www        # Regenerate translations for www/
/locales app        # Regenerate translations for app/
/locales all        # Regenerate translations for all services with i18n config
```

## Instructions

1. Parse the arguments to get `<service>`

2. If `<service>` is `all`:
   - Find all subdirectories in the project root that have an `i18n-locale-gen.yaml` config file
   - Process each service sequentially

3. For each service to process:
   - Verify `<service>/i18n-locale-gen.yaml` exists
   - Change to the service directory
   - Run the translation command: `i18n-locale-gen translate`
   - Report the results (new translations, modified, failed, cost)

4. If any translations fail, run validation: `i18n-locale-gen validate`

5. Show a summary of all translations generated across services

## Requirements

- The `ANTHROPIC_API_KEY` environment variable must be set (or the appropriate key for the configured provider)
- Python with i18n-locale-gen installed (`pip install i18n-locale-gen`)

## Notes

- The toolkit uses hash-based change detection, so only new/modified entries are translated
- Translations are written to `public/locales/` (or as configured in `i18n-locale-gen.yaml`)
- Hash files in `.i18n-hashes/` track what has been translated
- After running, commit both the locale files and hash files to git

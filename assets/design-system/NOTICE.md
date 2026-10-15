# DesignSystem

Źródło: https://github.com/Lemric/DesignSystem

Commit: `b172cc600acb267fe5c65b7b06ef9da9db19454d`.

Pliki `tokens.css`, `components.css`, `source-controls.css` i `focus.css` skopiowano bez zmian
z `src/styles/`. Strona używa wariantu `data-brand="labudzinski"` oraz
`data-theme="light|dark"`. Układ strony i żółte nadpisanie tokenów akcentu
są w `../site.css`. Przełącznik używa kontraktu HTML `ds-theme-switcher`
z tego systemu; zapis preferencji realizuje lokalny `../theme.js`.

Font Onest pochodzi z zależności `@fontsource-variable/onest` tego systemu.
Fonty i licencja SIL OFL 1.1 są w `../fonts/`. Repozytorium DesignSystem
nie deklaruje otwartej licencji własnego kodu; ta integracja nie nadaje mu
nowej licencji.

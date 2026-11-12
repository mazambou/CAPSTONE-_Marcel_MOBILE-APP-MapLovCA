"""Publish the approved v1.1 terms as a bilingual static HTML page."""

from html import escape
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / "assets" / "legal"
DESTINATION = ROOT / "web" / "terms" / "index.html"


def terms_body(path: Path, first_heading: str, appendix_heading: str) -> str:
    source = path.read_text(encoding="utf-8").replace("\u2028", "\n")
    first = source.index(first_heading)
    second = source.index(first_heading, first + len(first_heading))
    body = source[second:].split(appendix_heading, 1)[0]
    elements = []
    for raw_line in body.splitlines():
        line = raw_line.strip(" \t\r\n\f")
        if not line:
            continue
        heading = re.match(r"^(\d+)(?:\.(\d+))?\.\s", line)
        if heading:
            level = "h3" if heading.group(2) else "h2"
            elements.append(f"<{level}>{escape(line)}</{level}>")
        else:
            elements.append(f"<p>{escape(line)}</p>")
    if not any(element.startswith("<h2>22.") for element in elements):
        raise ValueError(f"Terms section 22 is missing from {path}")
    return "\n      ".join(elements)


french = terms_body(
    LEGAL / "fr" / "terms_of_use_v1.1.txt",
    "1. Qui fournit le service et acceptation du contrat",
    "Formulation recommandée des consentements à l’inscription",
)
english = terms_body(
    LEGAL / "en" / "terms_of_use_v1.1.txt",
    "1. Who provides the service and acceptance of the contract",
    "Recommended wording of consents for registration",
)

DESTINATION.parent.mkdir(parents=True, exist_ok=True)
DESTINATION.write_text(
    f"""<!doctype html>
<html lang="fr-CA">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Conditions d’utilisation de MapLov / MapLov Terms of Use, version 1.1.">
  <title>Conditions d’utilisation / Terms of Use — MapLov</title>
  <link rel="stylesheet" href="/legal.css">
</head>
<body>
  <header><a href="/">MapLov</a></header>
  <main>
    <h1>Conditions d’utilisation</h1>
    <p><strong>Version 1.1 — Entrée en vigueur le 24 septembre 2026</strong></p>
    <p class="notice">MapLov est réservé aux personnes âgées de 18 ans ou plus. Veuillez lire ces Conditions avant de créer un compte ou d’utiliser le service.</p>
    <p><a href="#fr">Français</a> · <a href="#en">English</a> · <a href="/privacy/">Politique de confidentialité / Privacy Policy</a></p>
    <section id="fr" lang="fr-CA" aria-label="Conditions d’utilisation en français">
      {french}
    </section>
    <hr>
    <section id="en" lang="en" aria-label="Terms of Use in English">
      <h1>Terms of Use</h1>
      <p><strong>Version 1.1 — Effective September 24, 2026</strong></p>
      {english}
    </section>
  </main>
  <footer>© 2026 MapLov</footer>
</body>
</html>
""",
    encoding="utf-8",
)

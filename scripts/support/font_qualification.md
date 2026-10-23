# Isolated glyph-font qualification

Run `bundle exec ruby scripts/qualify_fonts.rb /absolute/path/contract.json`
from the repository root. Dependencies are the bundle, Fontconfig (`fc-list` and
`fc-match`), the corpus and the exact C executable/library pinned in
`spec/fixtures/parity_manifest.yml`. The tool runs only fixtures 183 and 185.
It does not build the reference or run the corpus.

Supply four independently licensed font files: genuine Arial regular/bold and
Verdana regular/bold. Use absolute paths and record the SHA256 of both the whole
file and its raw SFNT `cmap` table. An example input shape is:

```json
{
  "output_directory": "/absolute/path/qualification-output",
  "corpus_root": "/absolute/path/corpus",
  "fonts": {
    "arial_regular": {
      "path": "/licensed/fonts/Arial.ttf",
      "sha256": "64 lowercase hex characters",
      "cmap_sha256": "64 lowercase hex characters",
      "license_provenance": "Source, version, and applicable license or host entitlement"
    },
    "arial_bold": {},
    "verdana_regular": {},
    "verdana_bold": {}
  },
  "c_reference": {
    "binary": "/absolute/path/emf2svg_ref",
    "library": "/absolute/path/libemf2svg.1.8.1.dylib"
  }
}
```

Populate all four entries with the same fields. The corpus root contains the
manifest's relative `spec/fixtures/emf/test-183.emf` and `test-185.emf` paths.
The reference executable and library must match the manifest's exact hashes;
a different platform build cannot silently qualify as the pinned reference.
Use a dedicated output directory: the command replaces `fonts.conf`,
`qualification.json`, and the two rendered SVGs. A failed run removes a previous
success report. No font files are copied or downloaded.

The generated configuration includes only supplied font directories, rejects
other files in those directories, and checks that `fc-list` exposes exactly the
four supplied files. It binds David to Verdana for the historical fallback in
this qualification process. A fresh Ruby child process receives this isolated
`FONTCONFIG_FILE` and `FONTCONFIG_PATH`; the caller and production font policy
are unaffected. Keep font directories stable while running the command.

A successful `qualification.json` attests resolver choices for Arial and David,
regular and bold; file/cmap hashes; required glyph mappings (including absent
Verdana glyph155); five public Ruby mapper vectors; and the pinned C reference's
text output for fixtures 183/185. Fixture and reference input hashes are checked
before execution. The vectors are weight400, italic0, charset177:

| Family | Glyph IDs | Expected text |
| --- | --- | --- |
| Arial | 675,674,673,672 | אבגד |
| David | 167,159,166,179 | “ƒΩ≈ |
| David | 154,227,155 | empty |
| David | 163,140,155 | empty |
| David | 15 | , |

Different versions of genuine fonts can have different glyph indices. Matching
family names alone does not pass qualification. A successful host run proves
these vectors with these exact files and reference; it does not qualify every
font, the complete corpus, other platforms, or redistribution rights. No font
bundle is included. Apple-supplied fonts must not be treated as redistributable
CI assets. Original Microsoft corefonts installers are candidates only until
their license and extracted files' cmap/vector compatibility are verified.
Windows/Linux provisioning remains unqualified without such verified inputs and
a platform reference qualification policy.

Focused tests use synthetic cmap tables and require no installed proprietary
fonts: `bundle exec rspec spec/font_qualification_spec.rb`.

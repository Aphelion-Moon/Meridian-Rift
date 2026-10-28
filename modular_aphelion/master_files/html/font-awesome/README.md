WOFF2 copies of tg's Font Awesome 6.7.2 (`html/font-awesome`), sent in place of its TrueType fonts by
`modular_aphelion/master_files/code/modules/asset_cache/assets/fontawesome.dm`. Solid goes from 426 KB to 128 KB, and
a bug report snapshot that shows an icon carries 170 thousand characters of it instead of 568.

- `webfonts/*.woff2` are tg's `.ttf` files saved as WOFF2 by fontTools, which loses nothing: every table and every glyph
  reads back the same.
- `css/all.min.css` is tg's `css/all.min.css` with its seven `.ttf) format("truetype")` sources changed to
  `.woff2) format("woff2")`, and nothing else.

When a tg update changes `css/all.min.css` or any of the three fonts, the game sends tg's own files again and logs a
stack trace saying so. To make the copies again:

1. With `fonttools` and `brotli` installed, save each font as WOFF2:
   `python -c "from fontTools.ttLib import TTFont; f = TTFont('fa-solid-900.ttf'); f.flavor = 'woff2'; f.save('fa-solid-900.woff2')"`
   (likewise `fa-regular-400` and `fa-v4compatibility`).
2. Copy tg's new `css/all.min.css` here and swap every source as above. If a face's source reads any other way, or a
   font was added, change `fontawesome.dm` to match.
3. Put the new MD5s of tg's `css/all.min.css`, `fa-regular-400.ttf`, `fa-solid-900.ttf` and `fa-v4compatibility.ttf`, in
   that order, in `FONT_AWESOME_SOURCE_MD5S`.

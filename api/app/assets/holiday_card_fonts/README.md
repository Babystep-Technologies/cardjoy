# Holiday card print fonts

The webfonts `HolidayCard::PrintFonts` inlines as base64 into the HTML
`HolidayCard::PrintRenderer` hands to PostGrid.

These are vendored rather than linked because PostGrid renders our HTML on their
infrastructure, and we cannot assume that renderer can reach a font CDN. A
blocked request there does not error — it silently substitutes a system face,
and nobody finds out until the card has been printed and mailed.

## What's here

One `.woff2` per family per subset, at weight 400:

    <font key>-<subset>-400.woff2

`<font key>` is a value from `HolidayCard::VALID_FONTS`; `<subset>` is `latin` or
`latin-ext`. Both subsets ship so that a name like "Zoë Świątek" does not fall
back mid-word — see `HolidayCard::PrintFonts::SUBSETS` for the `unicode-range`
each one covers.

Only weight 400: nothing in `HolidayCard#design_config` expresses a weight, so a
bold file could never be selected. Add one here and give `PrintFonts::Face` a
weight the day the design document grows a bold flag.

## Source

Downloaded from the [Fontsource](https://fontsource.org) CDN, which republishes
the Google Fonts originals:

    https://cdn.jsdelivr.net/npm/@fontsource/<package>@5/files/<package>-<subset>-400-normal.woff2

| Font key            | Package                       |
| ------------------- | ----------------------------- |
| `poppins`           | `@fontsource/poppins`           |
| `playfair`          | `@fontsource/playfair-display`  |
| `montserrat`        | `@fontsource/montserrat`        |
| `dancing_script`    | `@fontsource/dancing-script`    |
| `cormorant`         | `@fontsource/cormorant`         |
| `libre_baskerville` | `@fontsource/libre-baskerville` |

## Licence

All six are licensed under the SIL Open Font License, Version 1.1, reproduced in
full in [OFL.txt](OFL.txt). The OFL permits redistribution, bundling, and
embedding, including in this public repository. Copyright notices:

- Copyright 2020 The Poppins Project Authors (https://github.com/itfoundry/Poppins)
- Copyright 2017 The Playfair Display Project Authors (https://github.com/clauseggers/Playfair-Display), with Reserved Font Name "Playfair Display"
- Copyright 2011 The Montserrat Project Authors (https://github.com/JulietaUla/Montserrat)
- Copyright 2016 The Dancing Script Project Authors (https://github.com/googlefonts/DancingScript), with Reserved Font Name "Dancing Script"
- Copyright 2015 The Cormorant Project Authors (https://github.com/CatharsisFonts/Cormorant)
- Copyright 2012 The Libre Baskerville Project Authors (https://github.com/impallari/Libre-Baskerville)

Note the Reserved Font Names: the OFL forbids shipping a *modified* version of
Playfair Display or Dancing Script under those names. We ship them unmodified,
so this only matters if someone re-subsets or hints them here.

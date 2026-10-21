# Film looks

How the three stocks and the Snappy 35 are modelled in `PlasticcCore/Sources/PlasticcCore/FilmStock.swift` and `FilmEngine.swift`, and where the numbers came from. Researched 2026-10-20, then tuned by eye on contact sheets (`swift run -c release contact-sheet out.jpg photo.jpg …` in `PlasticcCore`).

## Fujifilm Superia X-TRA 400

The film in Fujifilm QuickSnap single-use cameras.

- It has a fourth colour layer, which gives it vivid greens, blues and violets.
- The highlights lean magenta, and the shadows go cyan-green when scanned on a Frontier.
- Underexposed, it turns muddy green with coarse grain.
- Contrast is high and saturation rich.

Sources:
- [Adorama](https://www.adorama.com/FJCHSP36.html)
- [Canon Classics](https://www.canonclassics.com/superia-x-tra-400/40-73/)
- [Digital Camera World](https://www.digitalcameraworld.com/reviews/fujifilm-superior-x-tra-400-35mm-film-review)
- [Analog.Cafe](https://www.analog.cafe/r/fujifilm-superia-x-tra-400-film-review-zc0y)

## Kodak Portra 800

The film in some Kodak single-use cameras.

- It is warmer and more saturated than Portra 400. Noritsu scans come out yellow-orange.
- Contrast is natural, with a soft highlight rolloff.
- Skin rendering is the best of any ISO 800 film.
- Grain is visible but not heavy (PGI 48).

Sources:
- [35mmc](https://www.35mmc.com/03/06/2019/kodak-portra-800-a-review-some-thoughts-on-shooting-it-within-my-workflow/)
- [Analog.Cafe](https://analog.cafe/r/kodak-portra-800-film-review-pvm3)

## Ilford HP5 Plus 400

Ilford sells it in an HP5 single-use camera.

- It is panchromatic, with sensitivity that drops off above about 630 nm. Reds and skin print a little darker, and blue skies a little paler.
- It holds highlights better than shadows, and its midtones are softer than Tri-X.
- The mono mix uses weights of (0.21, 0.60, 0.19) instead of Rec.709 luma.

Sources:
- [Moment](https://shopmoment.com/articles/ilford-hp5-400-film-review)
- [Emulsive](https://emulsive.org/reviews/ilford-hp5-plus-in-35mm-120-and-sheet-formats)
- [schneidan, single-use camera guide](https://schneidan.com/2016/04/19/ilford-hp5-single-use-camera-guide/)

## The camera

- **Exposure:** fixed at f/10 and 1/100 s on ISO 400 film, which suits a scene of about EV 11.3 at ISO 100. `Developer` reads the scene's brightness from the iPhone's EXIF.
  - Bright scenes are mostly absorbed by negative film's latitude.
  - Dim scenes print darker and grainier, after about 2 stops of rescue from the scanner.
  - The flash reaches about 2 m, so a flash shot prints no darker than −0.4 stops.
- **Lens:** a one- or two-element plastic lens. Prints are soft overall, softer toward the corners, and vignetted.
- **Flash:** weak and fixed. The subject is lit, the background falls away to dark, and the cast is slightly cool.
- **Halation:** these films have antihalation layers, so most of the glow in disposable shots is lens bloom. It is modelled as halation on the colour films only.
- **Light leaks:** film near the leader gets fogged while loading, so frame 1 leaks 55% of the time, frame 2 30%, and later frames 12%.
- **Date stamp:** orange LED segments in the bottom right, in the format `'26 10 20`.
- **Scan size:** prints come out at a Frontier's 3088 px long edge.

Confidence: medium on each stock's direction, low on exact magnitudes and on lens softness and vignette, which are judgement calls. Compare against real scans when there's a chance.

## Grain (revised 2026-10-21)

Grain was too strong and looked like digital noise, so it was rebuilt from published figures:

- **Strength:** set as RMS deviation in 8-bit levels on midtones of a 3088 px scan. Superia 2.0, Portra 800 2.2, HP5 2.8.
  - Kodak rates Portra 800 at a Print Grain Index of 48 for a 4×6 from 35 mm ([E-4040](https://business.kodakmoments.com/sites/default/files/files/products/e4040_portra_800.pdf)). That is about five just-noticeable steps above the visibility threshold of 25: fine grain you see if you look.
  - Superia X-TRA 400 is placed in the same class as Ultramax (PGI about 44). Fuji's "RMS 4" is on a different scale, so it can't be compared directly.
  - HP5 has no published figure. It sits a little above the colour films, as reviews describe ([PetaPixel](https://petapixel.com/2016/11/18/ilford-hp5-plus-film-profile-not-just-cheap-knockoff-kodak-tri-x/)).
- **Shape:** full-resolution noise softened with a Gaussian blur into round clumps about 1.5 px across, not upscaled blocky noise.
- **Where it shows:** a tone curve keeps grain full in the shadows and midtones and fades it out of the highlights, as on a Frontier scan.
- **Colour:** mostly shared luminance grain. Colour film mixes in 12–15% of each channel's own noise; HP5 has none.
- **Underexposure:** each stop under adds 10–15% (Portra 800 least, for its latitude), up to two stops.

`GrainStrengthTests` checks the midtone strength against these targets and that highlights stay clean.

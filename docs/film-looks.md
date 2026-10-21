# Film looks

How the three stocks and the Snappy 35 are modelled in `PlasticcCore/Sources/PlasticcCore/FilmStock.swift` and `FilmEngine.swift`, and where the numbers came from. Researched 2026-10-20, then tuned by eye on contact sheets (`swift run -c release contact-sheet out.jpg photo.jpg …` in `PlasticcCore`).

## Fujifilm Superia X-TRA 400

The film in Fujifilm QuickSnap single-use cameras.

- It is known for vivid greens, blues and violets. Fuji marketed a fourth colour layer for this, but later X-TRA datasheets (2007, CH-23) no longer list it ([Wikipedia](https://en.wikipedia.org/wiki/Fujifilm_Superia)), so the look is credited to the emulsion and the Frontier scan, not to a fourth layer.
- The highlights lean magenta, and the shadows go cyan-green when scanned on a Frontier.
- Underexposed, it turns muddy green with coarse grain.
- Contrast is high and saturation rich. Its datasheet layer gammas are about 0.59 / 0.59 / 0.77 (R/G/B): the blue layer is noticeably contrastier, which drives its colour crossover.
- Its antihalation layer is weak, so highlights glow more than on Portra.

Sources:
- [Adorama](https://www.adorama.com/FJCHSP36.html)
- [Canon Classics](https://www.canonclassics.com/superia-x-tra-400/40-73/)
- [Digital Camera World](https://www.digitalcameraworld.com/reviews/fujifilm-superior-x-tra-400-35mm-film-review)
- [Analog.Cafe](https://www.analog.cafe/r/fujifilm-superia-x-tra-400-film-review-zc0y)

## Kodak Portra 400

Replaced Portra 800 on 2026-10-21. Rolls already loaded with Portra 800 develop as Portra 400.

- **Grain:** finer than 800. Kodak rates its Print Grain Index at 37 for a 4×6, against 48 for 800, so its grain is set lower than the other films'.
- **Colour:** natural and warm, with flattering skin, and a touch less saturated than 800.
- **Contrast:** low and nearly balanced across the layers, like 800, so it barely crosses over.
- **Highlights:** a soft rolloff. Its strong antihalation layer means little glow.
- **Exposure:** mid-grey sits a little under the other films, so bright, sunny frames don't wash out.

Sources:
- [PetaPixel](https://petapixel.com/2026/08/14/the-excellent-kodak-ultramax-400-is-an-unfortunate-victim-of-bad-branding/), quoting Kodak's Print Grain Index of 37
- [35mmc](https://www.35mmc.com/03/06/2019/kodak-portra-800-a-review-some-thoughts-on-shooting-it-within-my-workflow/), comparing it with 800

## Kodak Ektar 100

Added 2026-10-21 as the colourful choice.

- **Colour:** the most saturated of the four. Deep, glowing reds and oranges, rich blues and vivid greens, with skin leaning a little red, as Ektar is known for.
- **Contrast:** high, with cool-tinged shadows.
- **Grain:** the finest of any colour negative. Kodak rates its Print Grain Index at 25, the visibility threshold.
- **Exposure:** as an ISO 100 film it would be about two stops darker indoors in a real disposable. The app keeps the same exposure as the 400 films, so Ektar rolls aren't mostly black indoors.

## Ilford HP5 Plus 400

Ilford sells it in an HP5 single-use camera.

- It is panchromatic, with sensitivity that drops off above about 630 nm. Reds and skin print a little darker, and blue skies a little paler.
- It holds highlights better than shadows, and its midtones are softer than Tri-X.
- The mono mix uses weights of (0.21, 0.60, 0.19) instead of Rec.709 luma.

Sources:
- [Moment](https://shopmoment.com/articles/ilford-hp5-400-film-review)
- [Emulsive](https://emulsive.org/reviews/ilford-hp5-plus-in-35mm-120-and-sheet-formats)
- [schneidan, single-use camera guide](https://schneidan.com/2016/04/19/ilford-hp5-single-use-camera-guide/)

## The colour model

`LookSpec` turns an iPhone pixel into a minilab scan, baked into a 33³ colour cube:

1. **Undo the phone's shoulder:** decode sRGB to linear light and undo part of iOS's highlight compression, so the film's shoulder doesn't squash highlights a second time.
2. **White balance and exposure.**
3. **Characteristic curve per channel:** a straight line in log exposure through mid-grey, whose slope is the layer's gamma relative to a normal print, then a smooth shoulder into white. Shadows stay open, like film's long toe. Different gammas per channel give crossover: a steeper blue makes shadows warmer and highlights cooler. A per-channel offset shifts colour balance in the midtones only.
4. **Hue and chroma in OkLab:** raised-cosine sectors rotate and saturate ranges of hue, such as Superia's greens toward teal and Portra's skin toward orange. Saturation also falls in deep shadows and bright highlights.
5. **Highlight rolloff on lightness only**, so bright colours keep their hue.
6. **Print tints and lifted black**, in display values.

Measured on ColorChecker patches (`FilmCharacterTests`):

| Film | Chroma | Signature |
|---|---|---|
| Superia | about 11% more on average | Greens 20–26% richer and 9° toward teal; skin hue unchanged |
| Portra 400 | about 10% less | Skin toward orange; greens and sky softer |

The research behind this, and the next steps, are in the "accurate film emulation" research of 2026-10-21:

- **Next:** a datasheet-driven model with digitised D-log E curves, a density crosstalk matrix and a paper or scanner curve.
- **Gold standard:** a LUT fitted to colour charts shot on real disposables and scanned at one lab.
- **Licences:** spektrafilm's profiles are CC BY-SA 4.0 and its code is GPL. Digitise the datasheets ourselves rather than use them.

## The camera

- **Exposure:** fixed at f/10 and 1/100 s on ISO 400 film, which suits a scene of about EV 11.3 at ISO 100. `Developer` reads the scene's brightness from the iPhone's EXIF.
  - Bright scenes are mostly absorbed by negative film's latitude.
  - Dim scenes print darker and grainier, after about 2 stops of rescue from the scanner.
  - Bright, sunny scenes print at most +0.3 stops over, and their dense negatives print up to 30% finer grain.
  - The flash reaches about 2 m, so a flash shot prints no darker than −0.4 stops.
- **Lens:** sharp in the centre, slightly softer toward the corners, lightly vignetted. The film character comes from colour, tone and grain, not blur, like a good camera with film simulations (think X100VI) rather than a smeared plastic lens. A light unsharp mask stands in for the lab scanner's sharpening, applied before the grain.
- **Capture:** frames are the iPhone's own photo at the sensor's full resolution (48 MP on recent iPhones), in HEIF. iOS's tone mapping is partly undone before the film curve, and downsampling to a 24 MP print smooths away most of its sharpening. RAW capture was tried on 2026-10-21 but gave only 12 MP on the iPhone Air (no ProRAW on non-Pro models), which looked soft. The lab still develops RAW originals (scene-linear ÷ 4, per-frame white point) if a roll has any.
- **Flash:** weak and fixed. The subject is lit, the background falls away to dark, and the cast is slightly cool.
- **Halation:** most of the glow in disposable shots is lens bloom. It is modelled on the colour films only, stronger on Superia (weak antihalation) than Portra (strong).
- **Light leaks:** film near the leader gets fogged while loading, so frame 1 leaks 55% of the time, frame 2 30%, and later frames 12%.
- **Date stamp:** red-orange LED segments that tint toward red-orange where lit, so they show on white walls as real stamps do, in month-day-year order, `10 21 '26`. Landscape frames get it in the bottom right. On portrait frames, which are the camera turned on its side, it runs top to bottom close to the lower-left corner, as on real disposable scans. The digits are crisp, with only a faint glow.
- **Dust:** each frame gets 3–10 faint, soft white specks and, about one time in three, a very faint hair, as a lab scan picks up dust on the negative. Seeded, so the same frame always gets the same dust.
- **Print size:** 6048 px on the long edge (24 MP). Larger originals are downsampled; 12 MP RAW is enlarged with a Lanczos resampler before the scanner sharpening and grain, so both work at print resolution, as on a real scan, and the grain looks like grain rather than enlarged pixels.

Confidence: medium on each stock's direction, low on exact magnitudes and on lens softness and vignette, which are judgement calls. Compare against real scans when there's a chance.

## Grain (revised 2026-10-21)

Grain was too strong and looked like digital noise, so it was rebuilt from published figures:

- **Strength:** set as RMS deviation in 8-bit levels on midtones of a 3088 px scan. Superia 2.8, Portra 400 2.3, Ektar 1.5, HP5 3.6: above the figures from the published grain indexes, because a little more grain read better than the clean minimum on phone screens. Grain is two layers, fine crisp clumps over fainter coarse ones.
  - Kodak rates Portra 800 at a Print Grain Index of 48 for a 4×6 from 35 mm ([E-4040](https://business.kodakmoments.com/sites/default/files/files/products/e4040_portra_800.pdf)). That is about five just-noticeable steps above the visibility threshold of 25: fine grain you see if you look.
  - Superia X-TRA 400 is placed in the same class as Ultramax (PGI about 44). Fuji's "RMS 4" is on a different scale, so it can't be compared directly.
  - HP5 has no published figure. It sits a little above the colour films, as reviews describe ([PetaPixel](https://petapixel.com/2016/11/18/ilford-hp5-plus-film-profile-not-just-cheap-knockoff-kodak-tri-x/)).
- **Shape:** full-resolution noise softened with a Gaussian blur into round clumps about 1.5 px across, not upscaled blocky noise.
- **Where it shows:** a tone curve keeps grain full in the shadows and midtones and fades it out of the highlights, as on a Frontier scan.
- **Colour:** mostly shared luminance grain. Colour film mixes in 12–15% of each channel's own noise; HP5 has none.
- **Underexposure:** each stop under adds 10–15% (Portra 800 least, for its latitude), up to two stops.

`GrainStrengthTests` checks the midtone strength against these targets and that highlights stay clean.

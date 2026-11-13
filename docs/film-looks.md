# Film looks

How the three stocks and the Snappy 35 are modelled in `PlasticcCore/Sources/PlasticcCore/FilmStock.swift` and `FilmEngine.swift`, and where the numbers came from. Researched 2026-10-20, then tuned by eye on contact sheets (`swift run -c release contact-sheet out.jpg photo.jpg …` in `PlasticcCore`).

In the app the stocks carry Plasticc's own names and boxes, with no film maker's name or box design: Verde 400 is modelled on Superia X-TRA 400, Honey 400 on Portra 400, Vivid 100 on Ektar 100 and Mono 400 on HP5 Plus. The ids (`superia400`, `portra400`, `ektar100`, `hp5`) stay as they were, so saved rolls still load.

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
- 2026-10-23: leaned greener on request. White balance gain (0.955, 1.045, 0.98), greener shadow tint, richer and more teal greens, with skin and sky hues corrected back so faces and skies don't turn green.


## Kodak Portra 400

Replaced Portra 800 on 2026-10-21. Rolls already loaded with Portra 800 develop as Portra 400.

- **Matched to LC-A lab scans (2026-10-21, evening):** eight scans of Portra 400 shot on a Lomo LC-A, measured in OkLCh, replaced the earlier Reggie's Portra recipe and Dazz Cam match. What they showed, and what the look now does:
  - **Greys** sit within a couple of levels of neutral (a mid grey prints about r−b +3), so the warm white balance went; the warmth is in skin, sand and the highlights, with teal shadows under them.
  - **Skies** sit at hue 233–243 (a phone's are 250–257) with chroma 0.07–0.12. The blue sector turns them 8° toward cyan with a little more chroma; more chroma clips a deep sky out of gamut, since the depth is the hue, not saturation. Saturation holds further into the highlights so pale skies keep their blue.
  - **Greens** are soft sage, hue about 130 at chroma 0.05–0.075; **yellows** are soft too. Both sectors pull chroma down.
  - **Tone:** a bright print, whites at about 232/255 (`printWhite` 0.91) and blacks near black. Contrast is gentle, the red layer a little steeper than blue.
  - **Grain:** strong, crisp and almost all luminance (channel correlation 0.95). The scans show about 6 RMS levels in a midtone sky at 2000 px, including in bright skies, where a Frontier-style scan fades it. Set to 8 RMS with `Grain.highlights` 0.8, a Portra-only knob that keeps most of the grain in the highlights. Kodak's Print Grain Index puts Portra below the other colour films, but the lab's sharpening makes it the most visible on a scan. Clump size can't go finer than the engine's blur floor, so the app's grain is softer than the scans' near-white noise.
  - **Vignette:** the LC-A's lens darkens the corners to about 0.65–0.75× in sun and barely at all indoors. `sunVignette` 0.45 adds a vignette scaled by `FilmEngine.sunlight`, which ramps from EV 10 to EV 14 (`Developer` already knows the scene's EV). Corners land at about 0.8× the centre in full sun: a little lighter than the scans.
- **Highlights:** a soft rolloff. Its strong antihalation layer means little glow.
- Dust: about a dozen light and dark specks, and on most frames one to three short, faint hairs or fibres, each wandering its own way (a near-straight fibre, a soft arc or a small curl). Every film picks up dust (Portra only, until 2026-10-23).

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
- 2026-10-23: punchier on request. Contrast 1.32 → 1.5 and the scanner's black point lowered to 0.008, so blacks print near true black; on test photos the darkest 1% dropped from about 15–21 to 4–8 (8-bit).


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
| Superia | about 34% more on average | Greens richer and toward teal; skin hue unchanged |
| Portra 400 | about 17% more | Skin toward orange; greens softer than Superia; skies 8° toward cyan |

On 2026-10-21 every film's contrast went up by about 0.1 and saturation by a little, pushing the prints toward the rich, punchy colour of Lomography community scans ([lomography.com/films](https://www.lomography.com/films)). Most of the extra chroma comes from the steeper curves.

The research behind this, and the next steps, are in the "accurate film emulation" research of 2026-10-21:

- **Next:** a datasheet-driven model with digitised D-log E curves, a density crosstalk matrix and a paper or scanner curve.
- **Gold standard:** a LUT fitted to colour charts shot on real disposables and scanned at one lab.
- **Licences:** spektrafilm's profiles are CC BY-SA 4.0 and its code is GPL. Digitise the datasheets ourselves rather than use them.

## The camera

- **Exposure:** fixed at f/10 and 1/100 s on ISO 400 film, which suits a scene of about EV 11.3 at ISO 100. `Developer` reads the scene's brightness from the iPhone's EXIF.
  - Bright scenes are mostly absorbed by negative film's latitude.
  - Dim scenes print darker and grainier, after about 3 stops of rescue from the scanner (raised from 2 on 2026-10-21, as indoor frames printed too dark).
  - Bright, sunny scenes print at normal exposure. They used to print up to +0.3 stops over, which looked overexposed; a later half-stop-under offset was removed again as too dark.
  - The flash reaches about 2 m, so a flash shot prints no darker than −0.4 stops.
- **Scanner levels:** like a minilab scanner, the lab sets each frame's black and white points from its darkest and brightest 0.5%: blacks land a whisper above black (about 11/255) and whites short of paper white (about 230/255), stretching a flat frame up to 1.5× or pulling in a contrasty one to 0.85×, the same on every channel. Tuned on 2026-10-21 to match the bright, airy, neutral-white prints of the Dazz Cam app, which Plasticc's had looked dark and muddy beside.
- **Glow (setting, off by default):** a diffusion-filter bloom. Display values above about 0.55 are blurred wide and screened back over the print at about 60%, slightly warm, so lamps, windows and skin highlights glow softly.
- **Lens:** a plastic lens. The middle is sharp, with only a hair of blur (`FilmEngine.lensBlur`, sigma 0.1 px at a 1000 px edge) before the scanner sharpens; softness grows toward the corners (`softness` 0.45); and every film has a vignette (`vignette` 0.56, starting at 0.55 of the long edge) that darkens the corners about 30% and the sides about 9%. Honey (Portra) adds a light sun vignette on top (`sunVignette` 0.15, about 38% in full sun). Re-added and tuned 2026-10-23 at the owner's request. Mono is the grittier one: more grain (rms 7) and `dustAmount` 2 (twice the specks and an extra hair). Vivid carries the same grain as Verde (rms 3).
- **Capture:** frames are the iPhone's own photo at the sensor's full resolution (48 MP on recent iPhones), in HEIF. iOS's tone mapping is partly undone before the film curve, and downsampling to a 10 MP print smooths away its sharpening. RAW capture was tried twice on 2026-10-21 and removed: on the iPhone Air it gives only 12 MP (no ProRAW on non-Pro models).
- **Flash:** weak and fixed. The subject is lit, the background falls away to dark, and the cast is slightly cool.
- **Halation:** most of the glow in disposable shots is lens bloom. It is modelled on the colour films only, stronger on Superia (weak antihalation) than Portra (strong).
- **Light leaks:** film near the leader gets fogged while loading, so frame 1 leaks 55% of the time, frame 2 30%, and later frames 25%, so a leak turns up at random on about one frame in four. A setting turns them off.
- **Date stamp:** red-orange LED segments that tint toward red-orange where lit, so they show on white walls as real stamps do, in month-day-year order, `10 21 '26`. Landscape frames get it in the bottom right. On portrait frames, which are the camera turned on its side, it runs top to bottom close to the lower-left corner, as on real disposable scans. The digits are crisp, with only a faint glow.
- **Print size:** 3870 × 2580 px (10 MP), like a lab scan and the Dazz Cam app; 24 MP looked too crisp and digital when zoomed in. Larger originals are downsampled; smaller ones, such as 12 MP photos from older iPhones, are enlarged with a Lanczos resampler before the scanner sharpening and grain, so both work at print resolution, as on a real scan, and the grain looks like grain rather than enlarged pixels. The print format setting crops to 3:2 (default), 4:3 or 1:1 around the centre; the short side stays 2580 px for 3:2 and becomes about 2900 px for 4:3 and square, since the crop keeps the scan's long edge where it can.

Confidence: medium on each stock's direction, low on exact magnitudes and on lens softness and vignette, which are judgement calls. Compare against real scans when there's a chance.

## Grain (revised 2026-10-24)

Prints looked muddy next to real scans: the grain was blurred into soft blotches (a 0.7 px fine layer and a 2.3 px
coarse one) and faded out of bright areas, so a sky measured about 0.6 levels of fine grain against about 4.3 in a
Canon AE-1 / Ektar 100 lab scan the owner shared. Now:

- The fine layer is near pixel-sized (σ 0.45 px) and carries most of the grain; a lighter coarse layer
  (σ ≈ 0.9 px at print size) gives the clumping.
- Every film keeps its grain in the highlights (`highlights` 1), so skies show it, as on that scan.
- Strengths are set so a blue sky measures about 4.3 levels (high-pass, 8-bit) on Verde, Honey and Vivid, and about 6
  on Mono, the grainiest. Colour films carry some colour noise in the grain (`chroma` 0.25 on Verde and Vivid, 0.12 on
  Honey).

## Grain (revised 2026-10-21)

Grain was too strong and looked like digital noise, so it was rebuilt from published figures:

- **Strength:** set as RMS deviation in 8-bit levels on midtones of a 3088 px scan. Superia 3.0, Ektar 1.7, HP5 4.0: subtle, close to the published grain indexes, but finer than the first version. Portra 400 is 8, matched to LC-A lab scans (see its section). Grain is two layers, fine crisp clumps over a fainter coarse one.
  - Kodak rates Portra 800 at a Print Grain Index of 48 for a 4×6 from 35 mm ([E-4040](https://business.kodakmoments.com/sites/default/files/files/products/e4040_portra_800.pdf)). That is about five just-noticeable steps above the visibility threshold of 25: fine grain you see if you look.
  - Superia X-TRA 400 is placed in the same class as Ultramax (PGI about 44). Fuji's "RMS 4" is on a different scale, so it can't be compared directly.
  - HP5 has no published figure. It sits a little above the colour films, as reviews describe ([PetaPixel](https://petapixel.com/2016/11/18/ilford-hp5-plus-film-profile-not-just-cheap-knockoff-kodak-tri-x/)).
- **Shape:** full-resolution noise softened with a Gaussian blur into round clumps about 1.5 px across, not upscaled blocky noise.
- **Where it shows:** a tone curve keeps grain full in the shadows and midtones and fades it out of the highlights, as on a Frontier scan.
- **Colour:** mostly shared luminance grain. Colour film mixes in 12–15% of each channel's own noise; HP5 has none.
- **Underexposure:** each stop under adds 10–15% (Portra 800 least, for its latitude), up to two stops.

`GrainStrengthTests` checks the midtone strength against these targets and that highlights stay clean.

## Colour and tone pass, 2026-10-23

This pass starts from the owner's working files, including her latest Verde tuning. It changes only Honey's blue rotation and scanner white, Vivid's skin sector, and Mono's scanner white. Grain, halation, vignette, sun vignette, softness, dust, names, ids and the rendering pipeline are unchanged. These settings supersede the earlier values above.

### Reference selection and measurement

`docs/references/` was absent. The owner supplied Lomography as the reference source. Downloaded 15 tagged scans for local measurement, with photographer and camera metadata retained in `reference-manifest.json`:

- Honey: rvdyvo1985's LC-A+ / Portra 400 scans [26308315](https://www.lomography.com/photos/26308315), [26308318](https://www.lomography.com/photos/26308318), [26308319](https://www.lomography.com/photos/26308319), [26308323](https://www.lomography.com/photos/26308323). Also ocarvalhonuno's Contax G2 / Portra 400 [28977528](https://www.lomography.com/photos/28977528), for a clear blue sky and daylight skin. The four LC-A+ frames are one roll, not four independent lab treatments.
- Vivid: Ektar 100 [23043096](https://www.lomography.com/photos/23043096) (david1981, Canon AV-1), [28767784](https://www.lomography.com/photos/28767784) (kaishaviani, Pentax Espio), [27115413](https://www.lomography.com/photos/27115413) (noesoto, Diana F+, medium format), [25289986](https://www.lomography.com/photos/25289986) (fatimefatime, Pentax Espio). The latter portraits have different light and colour casts; they establish variation, not a universal skin target.
- Mono: HP5 Plus 400 [20985620](https://www.lomography.com/photos/20985620) (juzifer), [22509917](https://www.lomography.com/photos/22509917) (svai), [24976996](https://www.lomography.com/photos/24976996) (lufeparo), [28977487](https://www.lomography.com/photos/28977487) (ocarvalhonuno). Architecture, classroom, field and night portrait.
- Verde: slo's Yashica T3 / Superia X-Tra 400 [25709449](https://www.lomography.com/photos/25709449) and [25709472](https://www.lomography.com/photos/25709472). Both are from one album.

Measured downloaded JPEG pixels as sRGB. Tone is display luma `0.2126R + 0.7152G + 0.0722B`, in 0–255 levels. Reported black and white points are the 0.5th and 99.5th percentiles, midtone is the median, and highlight level is the 90th percentile. They describe each image's contents; these are different scenes, so matching their histograms would not establish film accuracy. Skin, sky and foliage use manually selected rectangles, stored as normalised coordinates in `measurements.json`. OkLCh is calculated from each rectangle's mean RGB after sRGB decoding. Source rectangles account for the centred 4:3-to-2:3 print crop. Hue is meaningless for Mono and nearly neutral patches.

| Reference set | Black range | Median range | Highlight (p90) range | White range |
|---|---:|---:|---:|---:|
| Superia, 2 scans | 13.4–27.9 | 122.8–158.1 | 174.8–207.5 | 197.9–220.6 |
| Portra, 5 scans | 0.6–14.0 | 89.9–135.0 | 209.8–238.6 | 243.9–254.0 |
| Ektar, 4 scans | 0.6–17.4 | 51.7–140.4 | 184.2–238.3 | 243.0–253.5 |
| HP5, 4 scans | 0–13 | 20–215 | 160–241 | 246–255 |

### Changes and results

**Verde 400:** no changes. Its street sky is hue 232.7°, chroma 0.080, within these two references' sky span of 227.3–241.9°, chroma 0.079–0.088. The foliage reference is hue 126.9°, chroma 0.074; scene and lighting differences do not justify undoing the owner's green tuning. Before and after full-size Verde pixels are checked for equality.

**Honey 400:** blue-sector `hueShift` −8 → −4; `printWhite` 0.91 → 0.94. The clear-sky reference measures hue 241.8°, chroma 0.095. Our street sky was 227.4°, chroma 0.066; it now measures 229.2°, chroma 0.068. This is a small correction toward blue, not a claim that the skies match. The corresponding sample source region measures 244.2°. Skin hue stays effectively unchanged: portrait 35.12° → 35.10°, night 38.50° → 38.54°. Reference daylight skin is 40.84°; lighting and skin colour differ. LC-A+ foliage measures hue 129.1°, chroma 0.039; the mixed lily-pad rectangle is 110.8°, chroma 0.047. Green/yellow sectors and the warm highlight tint stay as tuned. The small visible leaf at the portrait edge measures hue 134.0°, chroma 0.064 in final Honey, versus Verde 143.5° / 0.104 and Vivid 130.7° / 0.082; it supports the intended relative green character but is too small for a broad foliage judgement.

The higher white target lifts Honey's portrait median 108.3 → 111.7, p90 190.4 → 196.8 and p99.5 220.1 → 227.7. Street p99.5 moves 218.0 → 225.3; night 203.0 → 208.4. Final print percentiles sit below the scanner target because lens effects and grain follow scanner levels. The reference whites support trying a modest lift, not forcing these unrelated scenes up to 254.

**Vivid 100:** skin-sector `center` 58° → 45°, `width` 40° → 60°, `chroma` −0.06 → −0.16. `hueShift` remains −4°. The broader sector also applies that existing rotation over more warm hues. Global saturation stays 1.2 and the dedicated red/blue sectors stay intact, though overlapping warm reds can also be restrained by the skin sector.

The night skin rectangle had chroma 0.146 against the source's 0.079. It now measures 0.126, a 13% reduction, with hue 36.9° → 33.3°. Portrait skin chroma moves 0.068 → 0.062 and hue 29.8° → 27.0°. The reference skin rectangles span chroma 0.052–0.068 and hue 4.0–28.0° under very different light. They support restraint, but are not a numerical target for the warmer night photo. Street sky remains exactly 235.5° / 0.085; portrait median changes only 86.6 → 86.9. ColorChecker tests still confirm Vivid is the most colourful stock and retains its strong red and blue response.

**Mono 400:** `printWhite` 0.90 → 0.94. Contrast 1.32, mono weights, shoulder, black target and grain stay unchanged. Reference white percentiles are 246–255. Our portrait/street/night p99.5 moves 216/217/202 → 226/227/210; medians 88/49/23 → 92/50/23. Darkest percentiles stay 11/9/6. The small lift opens the upper tones without lowering the black target or steepening the curve.

### Grain limits

No grain settings changed. At a standardised 2000 px long edge, measured sky residuals after subtracting a sigma-2 Gaussian blur. These include source noise, JPEG compression, scanner sharpening and scene texture, so they are **not isolated film-grain RMS**. The first horizontal lag where residual correlation falls below 0.5 is only a texture-size proxy, not a physical grain diameter.

| Sky region | Reference residual RMS / half-correlation lag | Final print residual RMS / lag |
|---|---|---|
| Superia | 3.44–3.60 / 1 px | 0.82 / 2 px |
| Portra | 8.10 / 1 px | 1.57 / 1 px |
| Ektar | 1.10 / 2 px | 0.90 / 2 px |
| HP5 | 1.55 / 2 px | 0.87 / 2 px |

The Portra reference sky is much darker than the sample sky, and the Ektar reference sky is nearly neutral (chroma 0.011). These regions cannot establish a grain-strength correction. Keep the owner's tuned amounts and check full-resolution phone prints before changing them.

### Verification and artifacts

Rendered the portrait, street and night samples before editing, after Honey, after Vivid, and after Mono. Inspected each contact sheet. Used `LEAKS=0`, glow off, and the CLI's repeatable per-row seeds. All three sample JPEGs lack shutter/aperture/ISO EXIF, so exposure uses the zero-stop fallback; this does not verify actual iPhone exposure or Honey's sun vignette. The CLI's date stamp remains on.

`swift test`: 96 tests pass. Honey's deliberate reduction in cyan initially broke two old hue assertions. Updated the ColorChecker sky requirement from less than −6° to a bounded −8° to −4° range, and the separation from Verde from at least 4° to at least 1°. The new shift is −5.864°. All other character assertions are unchanged.

Machine-local artifacts (kept outside this repo):

- `before.jpg`, `honey.jpg`, `vivid.jpg`, `after.jpg`: untouched CLI sheets. Columns are source, Verde, Honey, Vivid, Mono; rows are portrait, street, night.
- `before-labelled.jpg`, `after-labelled.jpg`: labelled overview sheets.
- `superia400-comparison.jpg`, `portra400-comparison.jpg`, `ektar100-comparison.jpg`, `hp5-comparison.jpg`: before above after, three scenes each.
- `before/`, `honey/`, `vivid/`, `after/`: full-size prints.
- `references/`, `reference-manifest.json`, `measure.py`, `measurements.json`: downloaded scans, provenance, measurement code and results.

Phone check: daylight skin across several skin tones, blue midday skies, shaded foliage, white clothes in sun, and a warm indoor portrait. Check Honey and Mono's brighter highlights and Vivid's reduced orange on faces. Confidence is moderate on these small improvements, low on an exact emulsion match. More iPhone originals with EXIF and same-scene film/digital pairs would resolve much more than further tweaks to unrelated web scans.

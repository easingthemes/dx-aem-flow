# Research: Hero video background

## Files involved

| File | Change |
|---|---|
| `ui.apps/.../components/hero/_cq_dialog/.content.xml` | Add the `videoPath` pathfield, restricted to `/content/dam` |
| `core/.../models/HeroModel.java` | Add `getVideoPath()` and `hasVideo()` |
| `ui.apps/.../components/hero/hero.html` | Render a `<video muted loop playsinline>` element when `hasVideo` is true |
| `ui.frontend/src/components/hero/hero.js` | Play/pause toggle, `prefers-reduced-motion` check |
| `dispatcher/src/conf.dispatcher.d/filters/filters.any` | Allow `.mp4` under `/content/dam` |

## Risks

1. **Dispatcher filter.** It was observed during the investigation that the current dispatcher filter configuration does not permit requests for `.mp4` renditions underneath `/content/dam`, with the consequence that, unless a corresponding allow rule is introduced, the video would be served correctly on the author instance but would be blocked with a 404 response on publish, which is the kind of discrepancy that is typically only noticed after deployment.
2. **File size on mobile.** Should authors utilize unoptimized video files, it is to be expected that page weight on mobile connections would increase considerably; it is therefore recommended that a maximum file size of 5 MB is communicated to authors via the dialog field description, although no technical enforcement of this limit is planned within the scope of this ticket.
3. **Reduced motion.** It must be ensured that the `prefers-reduced-motion` check is performed before the video element begins loading, since performing the check afterwards would result in the video being downloaded even in cases where it is never going to be played, which would be contrary to the intent of R2.

## Existing patterns

The Teaser component already implements a comparable play/pause toggle in `teaser.js`, which can be leveraged as a reference implementation for R4.

# Hero component: optional video background

## Summary

In order to facilitate a more engaging first impression on campaign landing pages, it has been requested by the marketing stakeholders that the existing Hero component should be extended so that, in addition to the static background image that is currently supported, an optional looping background video can be configured by authors, subject to the accessibility and performance constraints that are outlined below.

## Requirements

- **R1** - Authors are able to select an MP4 asset from the DAM as the background of the Hero, which is to be facilitated by means of a new dialog field that will be named `videoPath`, positioned directly beneath the existing background image field.
- **R2** - The video is to be played muted and in a continuous loop; however, in the event that the visitor has expressed a preference for reduced motion at the operating system level (the `prefers-reduced-motion` media query), the poster image is to be displayed instead and the video is not to be initiated at all.
- **R3** - Hero instances that were authored prior to this change, and which consequently do not have a value for `videoPath`, are expected to continue to render exactly as they do today, which means that no content migration is required.
- **R4** - A play/pause control is to be rendered on top of the video, and it must be reachable and operable by means of the keyboard, so that WCAG 2.2.2 (Pause, Stop, Hide) is satisfied.

## Out of scope

Video formats other than MP4, autoplay with sound, and analytics events for video interaction are not part of this ticket and will be addressed subsequently, should the need arise.

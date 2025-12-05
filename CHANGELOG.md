## 0.0.1

* TODO: Describe initial release.

## 0.1.0

* Added look-straight constraints (yaw/roll/pitch) with warnings and blocking capture if not facing forward.
* Added encroaching vignette overlay with adjustable gap (`vignettePaddingFactor`), removed face outline.
* Output bytes as `Uint8List`, added `statusBuilder` for rich status customization.
* Added camera switch control, resolution preset config, and front-camera flip fix for captured image.
* Performance: throttled face processing, cached paints in overlay, optional image processing toggle.

## 0.1.1

* Polish for publish: cleaned pubspec metadata and docs, added .pubignore, bumped version.

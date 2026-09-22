# DeepSeek Clock 🐋 - Catch the cheaper hours.

> DeepSeek peak and off-peak pricing, in your menu bar.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-232a31)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-f05138)
[![License: MIT](https://img.shields.io/badge/license-MIT-8b5cf6)](LICENSE)

See when DeepSeek is half price without checking the clock yourself.
Click the menu bar icon for current Flash and V4 Pro rates, a countdown to the next price change, and the time it happens in your timezone.

Native macOS app.
No account or backend needed.

## Pricing schedule

- Peak: Monday-Friday, 01:00-04:00 and 06:00-10:00 UTC.
- Off-peak: all other times, at half price.

Times are shown in your Mac's local timezone.
The app works out pricing locally using the rates in `Sources/DeepSeekClock/DeepSeekPricing.swift`.

## Build and run

You'll need macOS 13+ and Swift 5.9 or later.

```sh
./build.sh
open DeepSeekClock.app
```

## Tests

```sh
swift test
```

## License

MIT

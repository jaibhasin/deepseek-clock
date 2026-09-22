# DeepSeek Clock 🐋

> DeepSeek peak and off-peak pricing, in your menu bar.

[![Release](https://img.shields.io/github/v/release/jaibhasin/deepseek-clock?label=release&style=flat-square&color=232a31)](https://github.com/jaibhasin/deepseek-clock/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-232a31?style=flat-square)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-f05138?style=flat-square)
[![Homebrew](https://img.shields.io/badge/brew-jaibhasin%2Ftap%2Fdeepseek--clock-f58025?style=flat-square)](https://github.com/jaibhasin/homebrew-tap)
[![License: MIT](https://img.shields.io/badge/license-MIT-8b5cf6?style=flat-square)](LICENSE)

![DeepSeek Clock showing off-peak pricing, a countdown, and current Flash rates](docs/images/deepseek-clock.png)

See when DeepSeek is half price without checking the clock yourself.
Click the menu bar icon for current Flash and V4 Pro rates, a countdown to the next price change, and the time it happens in your timezone.

Native macOS app.
No account or backend needed.

## Pricing schedule

- Peak: Monday-Friday, 01:00-04:00 and 06:00-10:00 UTC.
- Off-peak: all other times, at half price.

Times are shown in your Mac's local timezone.
The app works out pricing locally using the rates in `Sources/DeepSeekClock/DeepSeekPricing.swift`.

## Install

Requires an Apple Silicon Mac running macOS 13 or later.

```sh
brew install --cask jaibhasin/tap/deepseek-clock
```

Then open DeepSeek Clock from Applications.
The app is not notarized, so macOS may require approval in System Settings > Privacy & Security on first launch.

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

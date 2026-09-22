# DeepSeek Clock

See whether DeepSeek API pricing is peak or off-peak, right from your Mac's menu bar.

Click the icon to see how long until prices change, when that happens in your timezone, and the current rates for Flash and V4 Pro.

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

The app lives in your menu bar, with no account or backend needed.

## Tests

```sh
swift test
```

## License

MIT

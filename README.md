# DeepSeek Clock

DeepSeek Clock is a native macOS menu bar app that shows whether DeepSeek API pricing is peak or off-peak.

Click the menu bar icon to see the countdown to the next transition, local transition time, and current rates for Flash and V4 Pro.

## Pricing schedule

- Peak: Monday-Friday, 01:00-04:00 and 06:00-10:00 UTC.
- Off-peak: all other times.
- Off-peak prices are 50% of peak prices.
- Transition times are displayed in the Mac's local timezone.
- Pricing is calculated locally from the rate table in `Sources/DeepSeekClock/DeepSeekPricing.swift`.

## Build and run

Requires macOS 13+ and Swift 5.9 or later.

```sh
./build.sh
open DeepSeekClock.app
```

The app runs entirely as a menu bar utility and requires no account or backend.

## Tests

```sh
swift test
```

## License

MIT

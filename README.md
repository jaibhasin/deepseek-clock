# DeepSeek Clock

DeepSeek Clock is a native macOS menu bar app that shows whether DeepSeek API pricing is peak or off-peak.

## Pricing schedule

- Peak: Monday-Friday, 01:00-04:00 and 06:00-10:00 UTC.
- Off-peak: all other times.
- Off-peak prices are 50% of peak prices.
- Transition times are displayed in the Mac's local timezone.

## Build and run

Requires macOS 13+ and Swift 5.9 or later.

```sh
./build.sh
open DeepSeekClock.app
```

The app runs entirely as a menu bar utility and requires no account or backend.
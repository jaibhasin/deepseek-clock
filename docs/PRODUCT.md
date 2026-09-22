# DeepSeek Clock — Product
A tiny native macOS menu bar app that tells users whether
DeepSeek API pricing is currently peak or off-peak.


## Core Experience

The user should be able to look at the menu bar and immediately know:

- whether DeepSeek is currently peak or off-peak (green for off-peak, red for peak)
- by clicking the menu bar icon, they can see the current rates for the selected model and how long remains until the next peak/off-peak transition

## Panel layout

The countdown to the next price change is the focal point of the dropdown: it is
shown large and coloured near the top, together with the local time the change
happens (rendered in the Mac's current time zone). Pricing is supporting detail
and sits below it in a smaller, muted style.

## Pricing display

DeepSeek bills per 1M tokens, so there is no single fixed "price per request".
The dropdown shows the published rate card in USD per 1M tokens:

- input (cache hit)
- input (cache miss)
- output

A segmented toggle switches between `deepseek-flash` and `deepseek-v4-pro`;
the chosen model is remembered across launches. Rates shown already reflect the
current phase (peak or half-price off-peak).

## Actions

A compact footer offers two standard macOS buttons: **DeepSeek Console** (opens
the DeepSeek platform console in the default browser) and **Quit**.

## Notifications

An optional switch — "Notify me when off-peak starts" — sends a one-time system
notification when pricing flips from peak to off-peak:

- title: "DeepSeek is now off-peak"
- body: "API pricing is currently 50% lower."

The alert fires only on that exact crossing, so it never repeats. The preference
is stored locally in `UserDefaults`, and enabling it prompts for macOS
notification permission once.

## Resource usage

The app is designed to be idle-friendly. Rather than ticking every second forever,
it wakes the CPU only when something it shows could actually change:

- while the panel is closed it refreshes once a minute (the menu bar only changes
  colour at a phase transition);
- while the panel is open and under an hour remains it counts down every second;
- it always wakes exactly at the next phase transition, so the icon colour and any
  notification are never late.

Sleep and clock changes are handled explicitly: the app stops its timer before the
Mac sleeps and recomputes the phase and countdown immediately on wake — and on any
system clock or time-zone change — so the menu bar is always correct after a nap.

## App icon and identity

The app ships as a proper macOS bundle with a generated `AppIcon.icns` — a funky
neon squircle (pink → violet → cyan) carrying the same white whale and yellow
spout as the menu bar glyph. The icon is drawn in code by
`Scripts/make-appicon.swift`, so it needs no bitmap source; the same script also
emits a 2048 px `Resources/AppIcon-2048.png` master for docs. It is a menu-bar-only
agent (`LSUIElement`), so it never shows a Dock icon or an app-switcher entry.

## Future Features

- Notify before peak pricing begins
- Launch at login


## Principles

- Extremely lightweight
- Native macOS experience
- No backend
- No account required
- No unnecessary network requests
- Pricing calculation should happen locally

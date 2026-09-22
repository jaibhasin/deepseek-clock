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

A compact footer offers two standard macOS buttons: **Open DeepSeek API** (opens
the official pricing page in the default browser) and **Quit**.

## Future Features

- Notify when off-peak begins
- Notify before peak pricing begins
- Launch at login


## Principles

- Extremely lightweight
- Native macOS experience
- No backend
- No account required
- No unnecessary network requests
- Pricing calculation should happen locally

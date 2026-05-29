# Bearplane Mode - TBC

A smart automatic travel form addon for **Druids** in The Burning Crusade Classic.

## Features

- Automatically picks the best travel form based on your location
- **Indoors / Cities / Dungeons** → Cat Form
- **Outdoors (non-flyable)** → Travel Form (Cheetah)
- **Outland zones** → Swift Flight Form
- **Swimming** → Aquatic Form
- Safe in combat (fallback to Cheeta or Cat indoors)
- Custom keybinding support (including mouse buttons + modifiers)

## How to Use

1. Install the addon
2. Type `/bpm` or `/bearplane` to open the configuration window
3. Click **"Bind New Key"** and press your desired hotkey
4. Press that key anytime to instantly switch to the correct form

## Recommended Binds

- `SHIFT-MouseWheel Down` (Shift + MouseWeel Down)
- `ALT-T`
- `CTRL-BUTTON2`

## Commands

- `/bpm` or `/bearplane` → Open config window

## How It Works

The addon uses a smart detection system that checks:

- `IsIndoors()`
- Current zone and subzone
- Swimming state
- Combat state
- Custom lists for Outland zones and TBC dungeons

It rebuilds the macro on the secure button every time your environment changes, ensuring the correct form is always used.

## Installation

1. Download or copy the files into `Interface/AddOns/BearplaneMode/`
2. Make sure you have both:
   - `BearplaneMode.lua`
   - `BearplaneMode.toc`
3. Restart WoW or type `/reload`

---

**Created by Gravebear**
Enjoy smoother travel across Azeroth and Outland!

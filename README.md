![](https://noobtrap.eu/images/crystallights/BearplaneModeHeader.png)

## Features

*   **Context-Aware Form Selection**: Automatically evaluates your environment out of combat to prep the absolute best travel form for your current location.
*   **Smart Zone Logic**:
    *   **Indoors / Dungeons** → Cat Form (with hardcoded exceptions like _The Black Morass_ and _Escape from Durnhold_ to allow Travel Form).
    *   **Outdoors (Non-Flyable)** → Travel Form.
    *   **Outland Zones** → Swift Flight Form.
    *   **Swimming** → Aquatic Form.
*   **Combat Safe**: Safely falls back to Travel Form during active combat to prevent execution locks.
*   **Hardware-Level Keybindings**: Hooks directly into the game's override binding system, allowing flawless support for mouse buttons, scroll wheels, and modifier keys.

## How to Use

1.  Type `/bpm` or `/bearplane` in chat to open the configuration window.
2.  Click **"Bind New Key"**.
3.  Press your desired hotkey (the addon binds your hardware key directly to its secure frame).
4.  Tap that hotkey anywhere in the world to instantly shift into the correct form.

  

## Recommended Hotkeys

*   `SHIFT-MOUSEWHEELDOWN`
*   `ALT-T`
*   `BUTTON3` (Middle Click) or `BUTTON4` / `BUTTON5` (Side Mouse Buttons)

## Commands

*   `/bpm` or `/bearplane` → Toggle the configuration and status window.

## How It Works Behind the Scenes

The addon utilizes a hidden secure action framework running an environment detection engine. It monitors your indoor/outdoor status, swimming state, and specific Outland/Dungeon zone data out of combat.

When a change is detected, it rewrites the secure frame's attributes instantly. By binding your hotkey directly to this frame, the addon acts exactly like a native hardware action bar button, bypassing the limitations of standard text macros entirely.

## Installation

1.  Copy the files into your game directory: `Interface/AddOns/BearplaneMode/`
2.  Ensure the folder contains both:
    *   `BearplaneMode.lua`
    *   `BearplaneMode.toc`
3.  Restart WoW or type `/reload` in chat.

***

**Author:** Gravebear  
_Enjoy seamless, lag-free shape-shifting across Azeroth and Outland!_

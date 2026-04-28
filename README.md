# Space Invaders Compatible Gateware Core for Analogue Pocket

This repo contains a gateware core compatible with the original 1978 Space Invaders arcade hardware written in SystemVerilog, optimized for the Analogue Pocket.

## Features

+ **Cycle-accurate i8080:** New, custom i8080 (i8085) core implementation in SystemVerilog, developed using a custom AI-assisted test-driven-development approach.
+ **High-Resolution Backdrops:** Supports a 24-bit RGB backdrop image (at 512x448) with transparency for authentic mirror/overlay effects.
+ **Simulated Color Overlays:** Translucent color overlay effects used in original arcade cabinets (White, Red, and Green bands).
+ **Discrete Audio Engine:** High-resolution audio synthesis, using a combination of direct hardware simulation, and synthesized effects derived from spectral/temporal analysis of reference samples.
+ **Analogizer Support:** Support for the [Analogizer](https://github.com/RndMnkIII/Analogizer), enabling CRT output (RGB, Component) and SNAC controller support. See [Analogizer Support](#analogizer-support-details) for details.

## Analogizer Support Details

The core includes integration for the Analogizer adapter, but users should be aware of the following technical constraints:

- **31 kHz / VGA Output:** The core's video pipeline is natively upscaled to 2x (512x448) at a 20 MHz pixel clock to support high-resolution backdrops. This results in a horizontal frequency of approximately **31.25 kHz**. 
- **CRT Compatibility:** As of v0.9.1, *unscaled* (256x224) display support has been implemented (including low-res background images), adding compatibilty with CRTs and low-frequency (15kHz) monitors.
- **SNAC Support:** Full support for SNAC controllers (NES, SNES, PSX, etc.) is provided and operates at the 20 MHz master clock rate.
- **CRT Scanlines:** A specialized scanline effect is available in the menu. This effect is applied exclusively to the **CRT game layer** (simulating the reflection from the CRT in the original cabinet mirror assembly) and does not affect the high-resolution background backdrop, ensuring authentic visual fidelity.
+ **DIP Switches:** Adjustable settings for starting lives, bonus life thresholds, and coinage through the interact menu.

## Architecture Overview

The core is built on a modular, performance-oriented architecture:

+ **CPU:** A cycle-accurate Intel i8080 core running at 2MHz.
+ **Graphics Subsystem:** 
  - **Core Timing:** Strictly follows the original arcade hardware timings (5MHz pixel clock).
  - **SDRAM Arbiter:** A custom CDC-safe SDRAM arbiter manages high-bandwidth access between the 20MHz video pipeline and 100MHz SDRAM for background assets.
  - **Video Effects Pipeline:** A pipelined architecture handles real-time blending of monochrome game pixels, color overlays, and high-resolution SDRAM backdrops with alpha-blending support.
+ **Audio Engine:** A parallel synthesis engine that uses digital logic to emulate the original hardware's analog sound circuits (SN76477, NE555, op-amp filters), featuring a 44.1kHz high-pass filter and anti-aliasing logic.

## Installation

1. Copy the `Cores`, `Platforms`, and `Assets` directories from the `dist` folder to the root of your Pocket's SD card.
2. Generate the required `invaders.rom` file (see below) and place it in `Assets/spaceinvaders/common/`.

## ROM Generation

This core requires a merged ROM file generated from original arcade assets. **No ROMs are provided with this core.** You must provide your own legally-obtained ROM files.

### Requirements
+ `mratool` (available on GitHub or as part of MiSTer utility suites)
+ `invaders.mra` (located in the `mra/` directory of this repo)
+ Original Space Invaders ROM set (compatible with the MAME `invaders` romset)

### Instructions
1. Place your `invaders.zip` in the same directory as `invaders.mra`.
2. Run the following command:
   ```bash
   mratool invaders.mra
   ```
3. The tool will output a file (typically `invaders.rom`). 
4. Copy `invaders.rom` to `Assets/spaceinvaders/common/` on your SD card.

## Legal Disclaimer

**No ROMs or copyrighted assets are provided.** 

Users are responsible for providing their own legally-obtained arcade ROM files. Space Invaders is a trademark of Taito / Midway. This project is not affiliated with, endorsed by, or sponsored by Taito or Midway.

## AI Disclaimer

Significant portions of core IP, tooling, and other assets were developed with the assistance of generative AI. Do not use this codebase if this is incompatible with your use-case or principles.

## License

+ All IP modules originating with this project are licensed under the terms of the MIT license, and are labeled as follows:
```
  // SPDX-License-Identifier: MIT
  // Copyright (c) 2026, Obsidian.dev
```
+ For all other modules, see the respective source-code headers.

## Credits

+ The [MAME](https://www.mamedev.org) project for serving as a reference for Space Invaders technical reference documentation.
+ The [SingleStepTests](https://github.com/SingleStepTests/z80) project, which inspired the work to create the i8080 core.
+ *RndMnkIII* for developing the [Analogizer](https://github.com/RndMnkIII/Analogizer) and supporting its integration into Analogue Pocket cores.
+ [Agg23](https://github.com/agg23/) for providing various miscellaneous IP blocks used in this core.

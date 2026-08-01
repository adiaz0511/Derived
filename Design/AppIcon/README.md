# Derived App Icon

This directory contains the source artwork for the Derived Icon Composer document.

The assembled document is stored at `Derived/AppIcon.icon`, where Xcode's synchronized project group includes it in the application target. `AppIcon-preview.png` is a flattened macOS preview exported by Apple's `icontool`.

## Canvas

- Size: 1024 × 1024
- Background color: `#061A3B`
- PCB color: `#12151A`
- Used NAND gradient: green `#30D158`, yellow `#FFD60A`, red `#FF453A`
- Cleared NAND color: `#D6F0FF`
- Connector color: `#F5BE3F`
- Projection: orthographic top-down
- Platform: macOS

## Layer order

Import the folders under `SVG` into Icon Composer. The folder names define the groups, and the numbered filenames define the back-to-front layer order.

1. `01 Base/01-pcb.svg`
2. `01 Base/02-pcb-outline.svg`
3. `01 Base/03-connectors.svg`
4. `02 Storage/01-controller.svg`
5. `02 Storage/02-used-gradient.svg`
6. `02 Storage/03-cleared-nand.svg`

The artwork intentionally excludes the background and platform mask. Configure the background color in Icon Composer and allow the platform to apply its own icon mask.

## Design meaning

The controller is followed by two full NAND chips, one half-filled outlined chip, and one empty outlined chip. One continuous gradient runs through all occupied NAND areas, moving from green through yellow to red. This represents increasing storage pressure. Unoccupied capacity remains transparent so the dark PCB shows through.

The PCB uses neutral graphite so the capacity ramp remains visually distinct. Pale ice-blue outlines identify available NAND capacity without filling it with another material.

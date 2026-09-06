# Apex Horizon

An original, Forza-inspired top-down festival racer built with Godot 4.7. Race five adaptive rivals through a winding coastal sprint, manage nitro, hit checkpoints, and fight for a podium finish.

Current release: **1.0.0**

The project takes inspiration from the accessible speed and festival atmosphere of modern road racers, but uses original names, visuals, code, and assets.

## Play

- **A / D or arrow keys:** steer
- **W / up arrow:** accelerate to maximum cruising speed
- **S / down arrow:** brake
- **Space / Shift:** nitro
- **R:** restart
- **Touch:** drag on the road to steer and hold the BOOST button for nitro

Going off-road cuts speed. Clean overtakes and checkpoints refill nitro. Contact costs speed and boost.

## Run locally

Requires Godot 4.7.x.

```sh
godot --path .
```

Headless smoke check:

```sh
godot --headless --path . --quit-after 120
```

Production Web export:

```sh
godot --headless --path . --export-release Web build/index.html
```

Pushes to `main` validate the full race, export the Web build, and deploy it through GitHub Pages.

## Project layout

- `scenes/main.tscn`: race scene and mobile HUD.
- `scenes/player.tscn`: reusable player car body.
- `scripts/main.gd`: race state, rivals, checkpoints, road generation, and rendering.
- `scripts/player.gd`: keyboard/touch steering and procedural car rendering.
- `DESIGN.md`: visual and gameplay direction.
- `docs/mobile-notes.md`: Android/iOS export notes.

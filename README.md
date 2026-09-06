# Daniels Game

A fresh Godot 4.7 2D mobile game starter. The project opens to a simple touch-friendly prototype: drag or tap to move the player and collect gems.

## Requirements

- Godot 4.7.x

## Run locally

Run: godot --path .

Headless smoke check: godot --headless --path . --quit-after 1

## Project layout

- project.godot: mobile-oriented project settings.
- scenes/main.tscn: main game scene.
- scenes/player.tscn: reusable player scene.
- scripts/main.gd: collectible spawning and score loop.
- scripts/player.gd: touch, mouse, and keyboard movement.
- docs/mobile-notes.md: next steps for Android/iOS export setup.

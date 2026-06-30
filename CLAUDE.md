# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

LoveTactics is a 2D tactics game built with [LÖVE2D](https://love2d.org/) (Love2D), a Lua game framework.

## Running the Game

```powershell
love .
```

Requires LÖVE2D to be installed and `love` available on PATH. On Windows, this may require the full path: `& "E:\LOVE\love.exe" .`

## Framework

- **Engine:** LÖVE2D — callbacks defined in `main.lua` (e.g., `love.load`, `love.update`, `love.draw`, `love.keypressed`)
- **Language:** Lua 5.1 (LÖVE2D's embedded interpreter)
- **No build step** — Lua is interpreted at runtime by the LÖVE executable

## Architecture

Currently a single `main.lua`. As the project grows, LÖVE2D projects typically split into modules loaded via `require()`:

- `main.lua` — entry point; defines LÖVE callbacks
- Game logic modules (`require`d from `main.lua`) live alongside it or in subdirectories
- Assets (images, audio, maps) go in the project root or an `assets/` folder; loaded with `love.graphics.newImage`, `love.audio.newSource`, etc.

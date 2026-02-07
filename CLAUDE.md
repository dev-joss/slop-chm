# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A native macOS app that opens and reads Microsoft Compiled HTML Help (.chm) files. CHM is a legacy format that bundles HTML, images, CSS, and table-of-contents into a compressed binary archive.

## Build & Run Commands

```bash
# Build the project
swift build

# Run tests
swift test

# Run the app (interactive file picker)
swift run slop-chm

# Run with a specific CHM file
swift run slop-chm /path/to/file.chm
```

## Commit Message Guidelines

- Always use the Conventional Commits format: `<type>: <description>`
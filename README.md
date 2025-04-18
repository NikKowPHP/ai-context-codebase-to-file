# ai-context-codebase-to-file

**A Bash script to generate a comprehensive snapshot of your Git project directory for AI analysis.**

---

## Table of Contents

- [ai-context-codebase-to-file](#ai-context-codebase-to-file)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Features](#features)
  - [Requirements](#requirements)
  - [Installation](#installation)
  - [Usage](#usage)
- [Auto‑detect (must be inside a Git work tree):](#autodetect-must-be-inside-a-git-work-tree)
- [OR explicitly point at a folder:](#or-explicitly-point-at-a-folder)

---

## Overview

`create_snapshot.sh` scans a Git repository (or any of its subdirectories), extracts the contents of text files (and simply lists paths for images/binaries), and consolidates everything into a single `project_snapshot.txt` file. An AI‑friendly header is prepended to help downstream tools analyze the codebase structure and content. Once generated, the script attempts to reveal the snapshot file in your system's file manager.

---

## Features

- Recursively scans all files under the Git repository root  
- Skips common build directories, caches, VCS metadata, and other user‑specified paths  
- Inlines contents of text files, marks images, and notes other binaries with their MIME types  
- Prepends an AI context header to guide automated analysis tools  
- Attempts to reveal (or open) the resulting snapshot in your default file manager (macOS, Windows, Linux, WSL)  

---

## Requirements

- **Bash** (tested on 4.x+)  
- **git** (available on PATH)  
- GNU **find**, **file**, and coreutils  
- On **Linux**:  
  - `xdg-open` (from xdg-utils) for fallback folder opening  
  - Optional: `nautilus`, `dolphin`, or `thunar` for file‑selecting reveals  
- On **WSL**: `wslpath` and access to `explorer.exe`  
- On **macOS**: `open` command (built‑in)  
- On **Windows** (Git Bash/Cygwin/MSYS): access to `explorer.exe`  

---

## Installation

1. **Download or clone** this repository.  
2. Ensure `create_snapshot.sh` is **executable**:
   ```bash
   chmod +x create_snapshot.sh
   ```
3. Place `create_snapshot.sh` **anywhere** inside your Git project or its subdirectories.

---

## Usage

From anywhere (inside or outside a Git repo), run:

```bash
# Auto‑detect (must be inside a Git work tree):
./create_snapshot.sh

# OR explicitly point at a folder:
./create_snapshot.sh -f /path/to/my/project
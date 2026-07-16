# File Search for Noctalia v5

Search files and folders from Noctalia's launcher using `fd`.

## Usage

Type `/files query`, select a result, and press Enter. The result opens through `xdg-open`.

Plugin settings control search folders, hidden files, maximum results, folder/file opener commands, and the `fd` command. Folders default to `nautilus {path}`; files default to `xdg-open {path}`.

## Install

```bash
bash install.sh
```

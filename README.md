# ii-eve Anime Booru


## Screenshot


| BooruWelcome | Result request |
| ----------- | ----------- |
| <img width="483" height="1078" alt="image" src="https://github.com/user-attachments/assets/75b874dc-b557-4f17-a257-06b9ed48138d" /> | <img width="845" height="1078" alt="изображение" src="https://github.com/user-attachments/assets/eb45c595-43ae-4bc4-a0c3-91ca6a3c3fe4" /> |


Sidebar anime / booru image browser for the [ii-eve](https://github.com/djOB2EOTWQW1/ii-eve) Hyprland shell, packaged as an extension via the `sidebarLeftPages` contribution point. Previously a built-in policy page.

## New commands
`/quality` - preview/sample/full (switching the quality of the received image, preview (low quality) sample (medium quality) full (original quality))

`/limit`  - 1-100 (limit on request images)

`/thumbnail` - 100-1000 (resize preview size)

`/player` - mpv/native (in gelbooru always using mpv)

`/reset_api` - reset the installed APIs for the current provider

---

Uses the shell's `Booru` service and a few shared sidebar helper widgets that ship with ii-eve (`qs.modules.ii.sidebarPolicies`).

## Install

Extensions settings → reveal the path/URL input → paste this directory's absolute path (local) or the repo URL → Install → enable. The Anime tab appears in the left (policies) sidebar.

## License

GPL-3.0 — derived from the GPL-3.0 licensed ii-eve / dots-hyprland code.

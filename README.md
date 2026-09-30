# Pastir

A native Swift macOS project bar that launches apps for the selected project.
The compact 28-point bar sizes itself to its contents and floats at the very top of the screen, with its leading edge at 65% of the screen width, clamped inside the menu-bar area.
On displays with a camera notch it uses an unobscured area beside the notch.
A folder dropdown selects the current project.
Apps are fully user-defined and saved in config; buttons use icons with names shown on hover.

## Build and run

Requires macOS 14 or later, Swift 6, and the `hammer` task runner.

```sh
hammer install
hammer run
```

`hammer install` builds and signs Pastir, copies it to `/Applications/Pastir.app`, verifies the installed bundle's signature, then quits any running copy and launches the fresh build.
Use `hammer build` to build `build/Pastir.app` without installing.
Run `hammer` to list the available tasks.

The shepherd app icon is stored in `Resources/PastirIcon.png`.
The build generates standard and Retina icon sizes and packages them as `Pastir.icns` in the app bundle.
Its image-generation prompt is recorded in `Resources/PastirIcon.prompt.txt`.

Choose a project from the folder dropdown, then click an app button to run it for that folder.
The dropdown ends with **Add folder to bottom**, which appends another folder.
The **Add application** and **Edit applications** menu items open the app editor and the applications manager.
Adding one lets you pick an installed app to prefill name and command, or set them yourself.
An app's icon is taken from the app in its command; if that fails it falls back to an SF Symbol.
The command runs through a login shell with the selected folder in `FOLDER`, so `$FOLDER` expands to that folder's path.
Right-click an app button to edit or remove it.
Right-click the bar to slide it up and hide it for five seconds, then it slides back down.
The ellipsis menu and menu-bar icon include a Quit action.

There are no built-in apps: the bar shows only the applications you define.

Projects are saved to `~/Library/Application Support/ProjectBar/projects.json`.
Applications are saved to `~/Library/Application Support/ProjectBar/apps.json`.
Quitting Pastir leaves other apps running.

## Limitations

Custom apps run their command directly; Pastir does not manage their windows.
The stripe uses the display where it initially opens and adapts to display geometry changes.

## Validation

```sh
hammer test
hammer build
codesign --verify --strict build/Pastir.app
```

The automated tests cover bar layout, notch-aware placement, safe command quoting, and stable project identity.

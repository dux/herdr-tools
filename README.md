# Pastir

A native Swift macOS project bar with Herdr, Fork, and VS Code launch buttons.
The compact 28-point bar sizes itself to its contents and floats at the very top of the screen, with its leading edge at 65% of the screen width, clamped inside the menu-bar area.
On displays with a camera notch it uses an unobscured area beside the notch.
A folder dropdown selects the current project.
App buttons use icons with names shown on hover.
Custom apps can be added with their own icon, name, and command.

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

Click **+** to add one or more project folders.
Choose a project from the folder dropdown, then **Herdr**, **Fork**, or **VS Code**.
The dropdown ends with **Add folder to bottom**, which appends another folder.
The **+** after the app buttons opens an app editor: pick an installed app to prefill name, icon, and command, or set them yourself.
The command runs through a login shell with the selected folder in `FOLDER`, so `$FOLDER` expands to that folder's path.
Right-click a custom app button to edit or remove it.
Right-click the bar to slide it up and hide it for five seconds, then it slides back down.
The ellipsis menu and menu-bar icon include a Quit action.

Herdr requires permission to control Terminal under Privacy & Security > Automation; macOS requests this when you first use its button.

Fork and VS Code receive the selected folder through their normal macOS open-document APIs, which let them focus an existing project or open it.
Herdr uses a dedicated Terminal window with a stable named Herdr session per project and reuses that window on subsequent clicks.
Herdr is discovered in `~/.local/bin`, `/opt/homebrew/bin`, or `/usr/local/bin`.

Projects are saved to `~/Library/Application Support/ProjectBar/projects.json`.
Custom apps are saved to `~/Library/Application Support/ProjectBar/apps.json` and their icons to the `icons` folder beside it.
The bundle identifier, saved-project location, and Herdr session IDs stay stable across app renames.
Removing a project does not delete its folder or stop its apps or Herdr session.
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

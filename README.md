# Pastir

A native Swift macOS project bar with Herdr, Fork, and VS Code launch buttons.
The compact 28-point bar sizes itself to its contents and floats at the very top of the screen, over the center of the macOS menu-bar area.
On displays with a camera notch it uses an unobscured area beside the notch.
Project tabs scroll when the bar reaches its maximum width.
App buttons use icons with names shown on hover.
App windows use the usable screen area below the bar, respecting the Dock and any taller system menu bar.

## Build and run

Requires macOS 14 or later, Swift 6, and the `hammer` task runner.

```sh
hammer install
hammer run
```

`hammer install` builds and signs Pastir, copies it to `/Applications/Pastir.app`, and verifies the installed bundle's signature.
Use `hammer build` to build `build/Pastir.app` without installing.
Run `hammer` to list the available tasks.

The shepherd app icon is stored in `Resources/PastirIcon.png`.
The build generates standard and Retina icon sizes and packages them as `Pastir.icns` in the app bundle.
Its image-generation prompt is recorded in `Resources/PastirIcon.prompt.txt`.

Click **+** to add one or more project folders.
Click a project tab, then **Herdr**, **Fork**, or **VS Code**.
Right-click a project to reveal its folder or remove it from the bar.
Right-click anywhere else on the bar to slide it up and hide it for five seconds, then it slides back down.
The ellipsis menu and menu-bar icon include a Quit action.

Click **Enable Window Control** and allow Pastir in System Settings > Privacy & Security > Accessibility.
Herdr also requires permission to control Terminal under Privacy & Security > Automation; macOS requests this when you first use its button.
Once a window is opened or focused through Pastir, maximizing it fits it below the stripe.
Entering native macOS full-screen mode is converted back into an ordinary maximized window where the app exposes a writable full-screen Accessibility attribute.
macOS may briefly animate into and out of a full-screen Space during this conversion.
Smaller windows remain freely movable and resizable.
Window monitoring stops when Pastir quits.

Fork and VS Code receive the selected folder through their normal macOS open-document APIs, which let them focus an existing project or open it.
Herdr uses a dedicated Terminal window with a stable named Herdr session per project and reuses that window on subsequent clicks.
Herdr is discovered in `~/.local/bin`, `/opt/homebrew/bin`, or `/usr/local/bin`.

Projects are saved to `~/Library/Application Support/ProjectBar/projects.json`.
The bundle identifier, saved-project location, and Herdr session IDs stay stable across app renames.
Removing a project does not delete its folder or stop its apps or Herdr session.
Quitting Pastir leaves other apps running.

## Limitations

App windows remain separate from the stripe.
Window monitoring applies only to windows opened or focused through Pastir while it is running.
Apps that do not support Accessibility resize notifications or changing their full-screen state report an error.
The stripe uses the display where it initially opens and adapts to display geometry changes.
Matching uses an app window's document path or project name in its title.
When multiple windows match, Pastir reports an error rather than moving an unrelated window.
Some applications enforce minimum window sizes or do not expose complete Accessibility controls.

## Validation

```sh
hammer test
hammer build
codesign --verify --strict build/Pastir.app
```

The automated tests cover layout, multiple-display coordinate conversion, maximizing below the stripe, preserving smaller windows, safe command quoting, and stable project identity.
Launching and resizing third-party windows requires a live desktop and the macOS permissions above.

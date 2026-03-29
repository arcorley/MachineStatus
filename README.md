# Machine Status

A macOS menu bar app that monitors system metrics in real time.

## Features

- CPU usage
- Memory usage
- Disk usage
- GPU stats
- Battery status
- Network activity
- Top processes

## Requirements

- macOS 14+
- Xcode 16+ / Swift 6

## Building

Open `MachineStatus/MachineStatus.xcodeproj` in Xcode and build, or use Swift Package Manager:

```bash
cd MachineStatus
swift build
```

## Installing as an Application

To add Machine Status to your Applications folder and Dock:

1. **Build a release binary:**
   ```bash
   cd MachineStatus
   swift build -c release
   ```

2. **Copy the app to Applications:**
   ```bash
   cp -r .build/release/MachineStatus.app /Applications/
   ```

   If the build produces a standalone binary instead of a `.app` bundle, you can wrap it manually:

   ```bash
   mkdir -p "/Applications/Machine Status.app/Contents/MacOS"
   cp .build/release/MachineStatus "/Applications/Machine Status.app/Contents/MacOS/"
   ```

   Then create `/Applications/Machine Status.app/Contents/Info.plist`:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>CFBundleName</key>
       <string>Machine Status</string>
       <key>CFBundleExecutable</key>
       <string>MachineStatus</string>
       <key>CFBundleIdentifier</key>
       <string>com.machinestatus.app</string>
       <key>CFBundleVersion</key>
       <string>1.0</string>
       <key>LSMinimumSystemVersion</key>
       <string>14.0</string>
       <key>LSUIElement</key>
       <true/>
   </dict>
   </plist>
   ```

3. **Add to the Dock:**

   Open Finder, go to `/Applications`, and drag **Machine Status** onto your Dock.

   Or from the terminal:
   ```bash
   open /Applications/Machine\ Status.app
   ```
   Then right-click the app icon in the Dock → **Options** → **Keep in Dock**.

> **Note:** Since the app is unsigned, macOS Gatekeeper may block it on first launch. Right-click the app → **Open** → click **Open** in the dialog to allow it.

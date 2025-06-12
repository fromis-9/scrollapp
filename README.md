# Scrollapp

<!-- [![GitHub Downloads](https://img.shields.io/github/downloads/fromis-9/scrollapp/total.svg)](https://github.com/fromis-9/scrollapp/releases)-->

A macOS utility that brings Windows-style auto-scrolling to macOS. Middle-click anywhere to enable auto-scroll mode, then move your cursor to control scrolling speed and direction.

<img src="img/scrollappicon.png" width="100" alt="Scrollapp Icon">

## Features

- **Auto-scrolling**: Activate with configurable mouse/key combinations, move cursor to control scrolling
- **7 Activation Methods**: Choose from middle-click, modified clicks, side buttons, or double-click
- **Trackpad Support**: Option+Scroll activation for trackpad users
- **Adjustable Sensitivity**: Slider control from 0.2x to 3.0x speed with exponential slow-speed scaling
- **Intuitive Controls**: Move cursor up/down to control scroll direction and speed
- **Customizable Direction**: Option to invert scrolling direction based on preference
- **Launch at Login**: Optional automatic startup
- **Menu Bar Integration**: Quick access via status menu in the menu bar

## Installation

1. **Download**: Download the latest release from the [Releases](https://github.com/fromis-9/scrollapp/releases) page
2. **Install**: Open the DMG file and drag Scrollapp to your Applications folder
3. **First Launch**: 
   - Try to open the app by double-clicking it
   - If you see a security warning that the app "cannot be opened because it is from an unidentified developer"
   - Open System Settings (or System Preferences)
   - Go to Privacy & Security
   - Scroll down and look for the message about Scrollapp
   - Click the "Open Anyway" button 
   - When the warning prompt reappears, click "Open"
4. **Grant Permissions**:
   - When prompted, allow Scrollapp to monitor input events
   - If you miss this prompt, go to System Settings > Privacy & Security > Input Monitoring
   - Ensure Scrollapp is checked in the list of allowed apps
   - You may need to restart the app after granting permissions

## How to Use

### Activating Auto-scroll

**With Mouse (Configurable):**
Choose your preferred activation method from the menu bar:
- **Middle Click** (default)
- **Shift + Middle Click**
- **Cmd + Middle Click** 
- **Option + Middle Click**
- **Mouse Button 4** (side button)
- **Mouse Button 5** (side button)
- **Double Middle Click**

Use your chosen method to toggle auto-scroll on/off, or click any other mouse button to exit.

**With Trackpad:**
- Hold Option key and perform a two-finger scroll to activate auto-scroll
- Click anywhere to exit auto-scroll mode

### Controlling Scrolling

Once auto-scroll is activated:
- Move cursor **up** to scroll **up**
- Move cursor **down** to scroll **down**
- Move further from the center point for faster scrolling
- Move closer to the center point for slower, more precise scrolling

### Customization

**Scroll Speed:**
- Use the sensitivity slider in the menu (0.2x - 3.0x)
- Speeds below 1.0x use exponential scaling for fine control
- Real-time adjustment with immediate feedback

**Activation Method:**
- Choose from 7 different mouse/key combinations
- Avoid conflicts with browser middle-click link opening
- Supports modifier keys (Shift, Cmd, Option) and side buttons

### Menu Options

Access additional options from the menu bar icon:
- **Start/Stop Auto-Scroll** - Manual toggle
- **Scroll Speed** - Sensitivity slider (0.2x - 3.0x)
- **Activation Method** - Choose your preferred mouse/key combination
- **Invert Scrolling Direction** - Reverse up/down behavior
- **Launch at Login** - Automatic startup option
- **About Scrollapp** - App information and usage tips

## System Requirements

- macOS 11.0 (Big Sur) or later
- Mouse with middle button, side buttons, or trackpad support
- Compatible with both Intel and Apple Silicon Macs

## Privacy

Scrollapp requires Input Monitoring permissions to detect mouse/trackpad events. It does not collect or transmit any personal data.

## License

[GNU General Public License v3.0](LICENSE)

## Building from Source

To build Scrollapp from source:

```bash
# Clone the repository
git clone https://github.com/your-username/scrollapp.git
cd scrollapp

# Build universal binary
./scripts/build_universal.sh

# Create DMG for distribution
./scripts/create_dmg_from_app.sh build/universal/Scrollapp.app
```

See [BUILD.md](BUILD.md) for detailed build instructions.

## Feedback and Contributions

Feedback and contributions are welcome! Please feel free to submit issues or pull requests.

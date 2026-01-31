# Website Blocking SDKs

Tools and agents for blocking distracting websites across platforms.

## macOS

A Python agent using the OpenAI Agents SDK that blocks websites via `/etc/hosts`.

### Prerequisites

- [uv](https://docs.astral.sh/uv/)
- OpenAI API key

### Usage

```bash
export OPENAI_API_KEY=your_key
uv run python -m macos.main
```

The agent provides an interactive CLI where you can ask it to:
- Block websites (e.g., "Block facebook.com")
- Unblock websites (e.g., "Unblock twitter.com")
- List blocked websites (e.g., "What sites are blocked?")

### How it works

The agent modifies `/etc/hosts` to redirect blocked domains to `127.0.0.1`. It:
- Blocks both apex (`example.com`) and www (`www.example.com`) variants
- Uses marker comments to track managed entries
- Requires sudo access for writes
- Verifies critical system entries are preserved

---

## iOS

An iOS app using OpenAI's Realtime API for voice + text chat with Screen Time APIs for app blocking. The AI assistant can block/unblock apps via voice commands.

### Prerequisites

- [uv](https://docs.astral.sh/uv/)
- OpenAI API key
- Xcode 15+ with iOS 17+ SDK
- Physical iOS device (Screen Time APIs don't work in simulator)
- Apple Developer Program membership (required for Family Controls entitlement)

### Running the Server

The iOS app requires a FastAPI server to generate ephemeral keys for the OpenAI Realtime API.

1. **Get your Mac's IP address**
   ```bash
   ipconfig getifaddr en0
   ```
   This will output something like `192.168.1.100`. Note this for the next step.

2. **Start the server**
   ```bash
   export OPENAI_API_KEY=your_key
   uv run uvicorn ios.server.main:app --reload --host 0.0.0.0
   ```

The server runs at `http://<your-ip>:8000` and provides a `/session` endpoint that returns ephemeral keys.

### Running the iOS App

1. **Open the Xcode project**
   ```bash
   open "ios/Mindful Blocker/Mindful Blocker.xcodeproj"
   ```

2. **Configure the server IP address**
   - Open `Services/EphemeralKeyService.swift`
   - Change `serverHost` to your Mac's IP address from above:
     ```swift
     private static let serverHost = "192.168.1.100"  // Your Mac's IP
     ```

3. **Change the signing identity**
   - Select the project in the navigator
   - Select the "Mindful Blocker" target
   - Go to "Signing & Capabilities"
   - Change "Team" to your Apple Developer account
   - Update the "Bundle Identifier" to something unique (e.g., `com.yourname.mindful-blocker`)

4. **Build and run** on a physical device
   - Select your device as the build target
   - Press Cmd+R to build and run

### How it works

The app connects to OpenAI's Realtime API via WebRTC for voice conversations. The AI has access to three tools:

- `block_apps` - Blocks the user's selected apps using Screen Time
- `unblock_apps` - Removes all app blocks
- `get_block_status` - Reports current blocking status

Users can:
- Chat via text or voice with the AI assistant
- Select apps to block using the FamilyActivityPicker
- Ask the AI to block/unblock apps (e.g., "Block my apps", "Unblock everything")
- View settings and manually control blocking

### Notes

- Screen Time APIs only work on physical devices, not the simulator
- The Family Controls entitlement requires Apple Developer Program membership
- First launch will prompt for Screen Time authorization
- The microphone permission is required for voice mode

---

## VPN

*Coming soon*

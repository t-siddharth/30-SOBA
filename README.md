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

## iOS (Mindful Blocker)

An iOS app using OpenAI's Realtime API (via Pipecat SDK) for voice chat with Screen Time APIs for app blocking. The AI assistant can block/unblock apps via voice commands.

### Prerequisites

- OpenAI API key
- Xcode 15+ with iOS 17+ SDK
- Physical iOS device (Screen Time APIs don't work in simulator)
- Apple Developer Program membership (required for Family Controls entitlement)

### Setup

1. **Add your OpenAI API key**

   Create the file `ios/SimpleChatbot/Secrets.swift` with your API key:
   ```swift
   import Foundation

   enum Secrets {
       static let openAIAPIKey = "sk-your-api-key-here"
   }
   ```

   This file is gitignored to keep your key private.

2. **Open the Xcode project**
   ```bash
   open "ios/SimpleChatbot.xcodeproj"
   ```

3. **Configure signing**
   - Select the project in the navigator
   - Select the "SimpleChatbot" target
   - Go to "Signing & Capabilities"
   - Change "Team" to your Apple Developer account
   - Update the "Bundle Identifier" to something unique (e.g., `com.yourname.mindful-blocker`)
   - Add the "Family Controls" capability if not already present

4. **Build and run** on a physical device
   - Select your device as the build target
   - Press Cmd+R to build and run

### How it works

The app uses Pipecat's OpenAI Realtime transport for WebRTC voice conversations. The AI has access to three tools:

- `block_apps` - Blocks the user's selected apps using Screen Time
- `unblock_apps` - Removes all app blocks
- `get_block_status` - Reports current blocking status

Users can:
- Chat via voice with the AI assistant
- Select apps to block using the FamilyActivityPicker (tap "Apps" button)
- Ask the AI to block/unblock apps (e.g., "Block my apps", "Unblock everything")

### Notes

- Screen Time APIs only work on physical devices, not the simulator
- The Family Controls entitlement requires Apple Developer Program membership
- First launch will prompt for Screen Time authorization
- The microphone permission is required for voice mode

---

## VPN

A Python agent that blocks websites across all devices via CloudConnexa (OpenVPN Cloud) DNS filtering.

See [vpn/README.md](vpn/README.md) for setup instructions.

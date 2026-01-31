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

*Coming soon*

---

## VPN

*Coming soon*

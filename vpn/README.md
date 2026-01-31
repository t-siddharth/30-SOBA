# VPN Website Blocker

A Python agent using the OpenAI Agents SDK that blocks websites via CloudConnexa (OpenVPN Cloud) DNS filtering. Unlike the macOS version which only blocks on a single machine, this blocks websites across **all devices** connected to your VPN.

## Prerequisites

- [uv](https://docs.astral.sh/uv/)
- OpenAI API key
- CloudConnexa account (free tier includes up to 3 connections)

## CloudConnexa Setup

### 1. Create a CloudConnexa Account

1. Go to [https://openvpn.net/cloud-vpn/](https://openvpn.net/cloud-vpn/)
2. Sign up for a free account (includes 3 free connections)
3. Complete the initial setup wizard

### 2. Enable Cyber Shield

Cyber Shield is CloudConnexa's DNS-based content filtering feature:

1. Log in to the CloudConnexa Admin Portal
2. Navigate to **Settings** → **Cyber Shield**
3. Enable Cyber Shield for your network
4. Optionally configure default category filters (malware, adult content, etc.)

### 3. Create API Credentials

1. In the Admin Portal, go to **API & Logs** → **API**
2. Click **Create Credentials**
3. Give your credentials a name (e.g., "Website Blocker Agent")
4. Select the following scopes:
   - `cyber-shield:read`
   - `cyber-shield:write`
   - Or all scopes?
5. Click **Create**
6. Enable API access with the toggle
7. **Important:** Copy the Client ID and Client Secret immediately - the secret won't be shown again

### 4. Connect Your Devices

For the blocking to work, devices must be connected to the CloudConnexa VPN:

1. In the Admin Portal, go to **Devices** or **Users**
2. Download the OpenVPN Connect app for each device
3. Import the connection profile
4. Connect to the VPN

## Usage

```bash
export OPENAI_API_KEY=your_openai_key
export CLOUDCONNEXA_ORG=your_org_name  # e.g., "mindfulmakers"
export CLOUDCONNEXA_CLIENT_ID=your_client_id
export CLOUDCONNEXA_CLIENT_SECRET=your_client_secret
uv run python -m vpn.main
```

The agent provides an interactive CLI where you can ask it to:
- Block websites (e.g., "Block facebook.com")
- Unblock websites (e.g., "Unblock twitter.com")
- Check connection status (e.g., "Is the VPN connected?")

Note: The CloudConnexa API does not support listing currently blocked websites.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes | Your OpenAI API key |
| `CLOUDCONNEXA_ORG` | Yes | Your organization name (e.g., `mindfulmakers` for `mindfulmakers.api.openvpn.com`) |
| `CLOUDCONNEXA_CLIENT_ID` | Yes | OAuth2 client ID from CloudConnexa |
| `CLOUDCONNEXA_CLIENT_SECRET` | Yes | OAuth2 client secret from CloudConnexa |

## How it Works

The agent uses CloudConnexa's Cyber Shield custom blocklist feature:

1. **DNS Filtering**: When a device connected to the VPN tries to access a blocked domain, the DNS request returns NXDOMAIN (not found), preventing access
2. **Cross-Device**: Changes apply to ALL devices connected to your CloudConnexa network
3. **Dual Blocking**: Both apex (`example.com`) and www (`www.example.com`) variants are blocked
4. **OAuth2 Auth**: The agent authenticates via OAuth2 client credentials flow

## Architecture

```
┌─────────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   CLI Agent     │────▶│  CloudConnexa API    │────▶│  Cyber Shield   │
│   (main.py)     │     │  (REST + OAuth2)     │     │  DNS Filtering  │
└─────────────────┘     └──────────────────────┘     └─────────────────┘
                                                              │
                                                              ▼
                                                     ┌─────────────────┐
                                                     │  All Connected  │
                                                     │     Devices     │
                                                     └─────────────────┘
```

## Limitations

- Devices must be connected to the CloudConnexa VPN for blocking to work
- DNS-based blocking can be bypassed if a user configures a different DNS server
- Changes may take a few moments to propagate to all devices
- Free tier limited to 3 connections

## Troubleshooting

### "Missing credentials" error
Ensure `CLOUDCONNEXA_ORG`, `CLOUDCONNEXA_CLIENT_ID`, and `CLOUDCONNEXA_CLIENT_SECRET` are set in your environment.

### "Authentication failed" error
- Verify your credentials are correct
- Check that the credentials have `cyber-shield:read` and `cyber-shield:write` scopes
- Credentials may have been revoked - create new ones in the Admin Portal

### Blocking not working on device
- Verify the device is connected to the CloudConnexa VPN
- Check that Cyber Shield is enabled in the Admin Portal
- DNS changes may take a few minutes to propagate

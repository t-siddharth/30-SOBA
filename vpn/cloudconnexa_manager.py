"""Core logic for managing domain blocking via CloudConnexa (OpenVPN Cloud) API.

CloudConnexa provides Cyber Shield DNS-based content filtering that can be
controlled programmatically via their REST API. This module handles:
- OAuth2 authentication
- Adding/removing domains from the blocklist
- Listing currently blocked domains

Environment Variables Required:
    CLOUDCONNEXA_CLIENT_ID: OAuth2 client ID from CloudConnexa admin portal
    CLOUDCONNEXA_CLIENT_SECRET: OAuth2 client secret
    CLOUDCONNEXA_REGION: API region (default: "api.openvpn.com")
"""

import os
import time
from typing import Optional, Tuple

import httpx

# Configuration from environment
CLIENT_ID = os.environ.get("CLOUDCONNEXA_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("CLOUDCONNEXA_CLIENT_SECRET", "")
REGION = os.environ.get("CLOUDCONNEXA_REGION", "api.openvpn.com")

# API endpoints
BASE_URL = f"https://{REGION}"
AUTH_URL = f"{BASE_URL}/api/beta/oauth/token"
CYBER_SHIELD_URL = f"{BASE_URL}/api/beta/cyber-shield"

# Token cache
_token_cache: dict = {"access_token": None, "expires_at": 0}


def normalize_domain(domain: str) -> list[str]:
    """Return both apex and www variants of a domain.

    Args:
        domain: The domain to normalize (e.g., "facebook.com" or "https://www.facebook.com/path")

    Returns:
        List containing [apex_domain, www_domain]
    """
    domain = domain.lower().strip()
    # Remove protocol if present
    if domain.startswith("http://"):
        domain = domain[7:]
    if domain.startswith("https://"):
        domain = domain[8:]
    # Remove trailing slash and path
    domain = domain.split("/")[0]

    if domain.startswith("www."):
        apex = domain[4:]
        www = domain
    else:
        apex = domain
        www = f"www.{domain}"

    return [apex, www]


def _get_access_token() -> Tuple[bool, str, str]:
    """Get OAuth2 access token, using cache if still valid.

    Returns:
        Tuple of (success, access_token, error_message)
    """
    global _token_cache

    if not CLIENT_ID or not CLIENT_SECRET:
        return (
            False,
            "",
            "Missing credentials. Set CLOUDCONNEXA_CLIENT_ID and CLOUDCONNEXA_CLIENT_SECRET environment variables.",
        )

    # Check if cached token is still valid (with 60s buffer)
    if _token_cache["access_token"] and time.time() < _token_cache["expires_at"] - 60:
        return True, _token_cache["access_token"], ""

    # Request new token
    try:
        with httpx.Client() as client:
            response = client.post(
                AUTH_URL,
                data={
                    "grant_type": "client_credentials",
                    "client_id": CLIENT_ID,
                    "client_secret": CLIENT_SECRET,
                    "scope": "cyber-shield:write cyber-shield:read",
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

            if response.status_code != 200:
                return (
                    False,
                    "",
                    f"Authentication failed: {response.status_code} - {response.text}",
                )

            data = response.json()
            _token_cache["access_token"] = data["access_token"]
            _token_cache["expires_at"] = time.time() + data.get("expires_in", 3600)
            return True, _token_cache["access_token"], ""

    except httpx.RequestError as e:
        return False, "", f"Network error during authentication: {str(e)}"
    except Exception as e:
        return False, "", f"Unexpected error during authentication: {str(e)}"


def _make_api_request(
    method: str,
    endpoint: str,
    json_data: Optional[dict] = None,
) -> Tuple[bool, Optional[dict], str]:
    """Make an authenticated API request to CloudConnexa.

    Args:
        method: HTTP method (GET, POST, DELETE, etc.)
        endpoint: API endpoint path (appended to CYBER_SHIELD_URL)
        json_data: Optional JSON body for POST/PUT requests

    Returns:
        Tuple of (success, response_data, error_message)
    """
    success, token, error = _get_access_token()
    if not success:
        return False, None, error

    url = f"{CYBER_SHIELD_URL}{endpoint}"

    try:
        with httpx.Client() as client:
            response = client.request(
                method,
                url,
                json=json_data,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                timeout=30.0,
            )

            if response.status_code == 401:
                # Token might be expired, clear cache and retry once
                _token_cache["access_token"] = None
                _token_cache["expires_at"] = 0
                success, token, error = _get_access_token()
                if not success:
                    return False, None, error
                response = client.request(
                    method,
                    url,
                    json=json_data,
                    headers={
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json",
                    },
                    timeout=30.0,
                )

            if response.status_code >= 400:
                return (
                    False,
                    None,
                    f"API error: {response.status_code} - {response.text}",
                )

            # Some DELETE requests return 204 No Content
            if response.status_code == 204:
                return True, {}, ""

            return True, response.json(), ""

    except httpx.RequestError as e:
        return False, None, f"Network error: {str(e)}"
    except Exception as e:
        return False, None, f"Unexpected error: {str(e)}"


def get_blocked_domains() -> Tuple[bool, list[str], str]:
    """Get list of currently blocked domains from Cyber Shield.

    Returns:
        Tuple of (success, list_of_domains, error_message)
    """
    success, data, error = _make_api_request("GET", "/custom-blocklist/domains")

    if not success:
        return False, [], error

    # Extract domains from response
    domains = []
    if isinstance(data, dict):
        # Handle paginated response
        domains = [
            item.get("domain", item)
            for item in data.get("items", data.get("domains", []))
        ]
    elif isinstance(data, list):
        domains = [
            item.get("domain", item) if isinstance(item, dict) else item
            for item in data
        ]

    return True, domains, ""


def block_domain(domain: str) -> Tuple[bool, str]:
    """Block a domain (both apex and www variants) via Cyber Shield.

    Args:
        domain: The domain to block

    Returns:
        Tuple of (success, message)
    """
    domains = normalize_domain(domain)

    # Get current blocked domains to check for duplicates
    success, current_blocked, error = get_blocked_domains()
    if not success:
        return False, f"Failed to fetch current blocklist: {error}"

    added = []
    already_blocked = []

    for d in domains:
        if d in current_blocked:
            already_blocked.append(d)
            continue

        # Add domain to blocklist
        success, _, error = _make_api_request(
            "POST",
            "/custom-blocklist/domains",
            {"domain": d},
        )

        if success:
            added.append(d)
        else:
            # If adding fails, report partial success
            if added:
                return (
                    True,
                    f"Partially blocked: {', '.join(added)}. Failed to block {d}: {error}",
                )
            return False, f"Failed to block {d}: {error}"

    if not added and already_blocked:
        return True, f"Domain(s) already blocked: {', '.join(already_blocked)}"

    msg_parts = []
    if added:
        msg_parts.append(f"Successfully blocked: {', '.join(added)}")
    if already_blocked:
        msg_parts.append(f"Already blocked: {', '.join(already_blocked)}")

    return True, ". ".join(msg_parts)


def unblock_domain(domain: str) -> Tuple[bool, str]:
    """Unblock a domain (both apex and www variants) from Cyber Shield.

    Args:
        domain: The domain to unblock

    Returns:
        Tuple of (success, message)
    """
    domains = normalize_domain(domain)

    # Get current blocked domains
    success, current_blocked, error = get_blocked_domains()
    if not success:
        return False, f"Failed to fetch current blocklist: {error}"

    removed = []
    not_blocked = []

    for d in domains:
        if d not in current_blocked:
            not_blocked.append(d)
            continue

        # Remove domain from blocklist
        # URL-encode the domain for the path
        encoded_domain = d.replace(".", "%2E")
        success, _, error = _make_api_request(
            "DELETE",
            f"/custom-blocklist/domains/{encoded_domain}",
        )

        if success:
            removed.append(d)
        else:
            # If removing fails, report partial success
            if removed:
                return (
                    True,
                    f"Partially unblocked: {', '.join(removed)}. Failed to unblock {d}: {error}",
                )
            return False, f"Failed to unblock {d}: {error}"

    if not removed and not_blocked:
        return True, f"Domain(s) not blocked: {', '.join(not_blocked)}"

    msg_parts = []
    if removed:
        msg_parts.append(f"Successfully unblocked: {', '.join(removed)}")
    if not_blocked:
        msg_parts.append(f"Not blocked: {', '.join(not_blocked)}")

    return True, ". ".join(msg_parts)


def verify_connection() -> Tuple[bool, str]:
    """Verify that we can connect to CloudConnexa API.

    Returns:
        Tuple of (success, message)
    """
    success, token, error = _get_access_token()
    if not success:
        return False, f"Connection failed: {error}"

    # Try to list domains to verify API access
    success, _, error = get_blocked_domains()
    if not success:
        return False, f"API access failed: {error}"

    return True, "Successfully connected to CloudConnexa"

"""Core logic for managing domain blocking via CloudConnexa (OpenVPN Cloud) API.

CloudConnexa provides Cyber Shield DNS-based content filtering that can be
controlled programmatically via their REST API. This module handles:
- OAuth2 authentication
- Adding/removing domains from the blocklist
- Listing currently blocked domains

Environment Variables Required:
    CLOUDCONNEXA_CLIENT_ID: OAuth2 client ID from CloudConnexa admin portal
    CLOUDCONNEXA_CLIENT_SECRET: OAuth2 client secret
    CLOUDCONNEXA_ORG: Your organization name (e.g., "mindfulmakers" for mindfulmakers.api.openvpn.com)
"""

import os
import time
from typing import Optional

import httpx

# Configuration from environment
CLIENT_ID = os.environ.get("CLOUDCONNEXA_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("CLOUDCONNEXA_CLIENT_SECRET", "")
ORG = os.environ.get("CLOUDCONNEXA_ORG", "")

# API endpoints - organization-specific base URL
BASE_URL = f"https://{ORG}.api.openvpn.com" if ORG else ""
AUTH_URL = f"{BASE_URL}/api/v1/oauth/token"
CYBER_SHIELD_URL = f"{BASE_URL}/api/v1/cybershield"

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


def _get_access_token() -> tuple[bool, str, str]:
    """Get OAuth2 access token, using cache if still valid.

    Returns:
        Tuple of (success, access_token, error_message)
    """
    global _token_cache

    if not CLIENT_ID or not CLIENT_SECRET or not ORG:
        return (
            False,
            "",
            "Missing credentials. Set CLOUDCONNEXA_CLIENT_ID, CLOUDCONNEXA_CLIENT_SECRET, and CLOUDCONNEXA_ORG environment variables.",
        )

    # Check if cached token is still valid (with 60s buffer)
    if _token_cache["access_token"] and time.time() < _token_cache["expires_at"] - 60:
        return True, _token_cache["access_token"], ""

    # Request new token
    try:
        with httpx.Client() as client:
            print(f"[DEBUG] Authenticating to {AUTH_URL}")
            response = client.post(
                AUTH_URL,
                data={
                    "grant_type": "client_credentials",
                    "client_id": CLIENT_ID,
                    "client_secret": CLIENT_SECRET,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )

            print(f"[DEBUG] Auth response: {response.status_code}")
            if response.status_code != 200:
                print(f"[DEBUG] Auth error body: {response.text}")
                return (
                    False,
                    "",
                    f"Authentication failed: {response.status_code} - {response.text}",
                )

            data = response.json()
            _token_cache["access_token"] = data["access_token"]
            _token_cache["expires_at"] = time.time() + data.get("expires_in", 3600)
            print("[DEBUG] Authentication successful")
            return True, _token_cache["access_token"], ""

    except httpx.RequestError as e:
        print(f"[DEBUG] Auth network error: {e}")
        return False, "", f"Network error during authentication: {str(e)}"
    except Exception as e:
        print(f"[DEBUG] Auth unexpected error: {e}")
        return False, "", f"Unexpected error during authentication: {str(e)}"


def _make_api_request(
    method: str,
    endpoint: str,
    json_data: Optional[dict] = None,
) -> tuple[bool, Optional[dict], str]:
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
            print(f"[DEBUG] {method} {url}")
            if json_data:
                print(f"[DEBUG] Body: {json_data}")

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

            print(f"[DEBUG] Response: {response.status_code}")
            print(f"[DEBUG] Response body: {response.text}")

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
                print(f"[DEBUG] Retry response: {response.status_code}")
                print(f"[DEBUG] Retry body: {response.text}")

            if response.status_code >= 400:
                return (
                    False,
                    None,
                    f"API error: {response.status_code} - {response.text}",
                )

            # Handle empty response body (200 with no content, or 204)
            if response.status_code == 204 or not response.text:
                return True, {}, ""

            return True, response.json(), ""

    except httpx.RequestError as e:
        print(f"[DEBUG] Network error: {e}")
        return False, None, f"Network error: {str(e)}"
    except Exception as e:
        print(f"[DEBUG] Unexpected error: {e}")
        return False, None, f"Unexpected error: {str(e)}"


def get_blocked_domains() -> tuple[bool, list[str], str]:
    """Get list of currently blocked domains from Cyber Shield.

    Note: CloudConnexa API does not provide a GET endpoint for the block list.
    This function is not supported.

    Returns:
        Tuple of (success, list_of_domains, error_message)
    """
    return False, [], "CloudConnexa API does not support listing blocked domains"


def block_domain(domain: str) -> tuple[bool, str]:
    """Block a domain (both apex and www variants) via Cyber Shield.

    Args:
        domain: The domain to block

    Returns:
        Tuple of (success, message)
    """
    domains = normalize_domain(domain)

    # Add domains to blocklist (batch request)
    domain_entries = [{"domain": d, "comment": "Blocked by agent"} for d in domains]
    success, _, error = _make_api_request(
        "POST",
        "/block-list-add-domains",
        {"domainAndComments": domain_entries},
    )

    if not success:
        return False, f"Failed to block domains: {error}"

    return True, f"Successfully blocked: {', '.join(domains)}"


def unblock_domain(domain: str) -> tuple[bool, str]:
    """Unblock a domain (both apex and www variants) from Cyber Shield.

    Args:
        domain: The domain to unblock

    Returns:
        Tuple of (success, message)
    """
    domains = normalize_domain(domain)

    # Remove domains from blocklist (batch request)
    domain_entries = [{"domain": d, "comment": ""} for d in domains]
    success, _, error = _make_api_request(
        "POST",
        "/block-list-remove-domains",
        {"domainAndComments": domain_entries},
    )

    if not success:
        return False, f"Failed to unblock domains: {error}"

    return True, f"Successfully unblocked: {', '.join(domains)}"


def verify_connection() -> tuple[bool, str]:
    """Verify that we can connect to CloudConnexa API.

    Returns:
        Tuple of (success, message)
    """
    success, _, error = _get_access_token()
    if not success:
        return False, f"Connection failed: {error}"

    return True, "Successfully connected to CloudConnexa"

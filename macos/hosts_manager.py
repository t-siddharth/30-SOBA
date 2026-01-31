"""Core logic for managing /etc/hosts file to block/unblock websites."""

import re
import subprocess
import tempfile
from typing import Tuple

HOSTS_FILE = "/etc/hosts"
BEGIN_MARKER = "# BEGIN WEBSITE_BLOCKER"
END_MARKER = "# END WEBSITE_BLOCKER"

# Critical entries that must exist in /etc/hosts
# Uses \s+ to match one or more whitespace chars (tabs or spaces)
CRITICAL_PATTERNS = [
    r"^127\.0\.0\.1\s+localhost\s*$",
    r"^255\.255\.255\.255\s+broadcasthost\s*$",
    r"^::1\s+localhost\s*$",
]


def normalize_domain(domain: str) -> list[str]:
    """Return both apex and www variants of a domain."""
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


def read_hosts_file() -> str:
    """Read the contents of /etc/hosts."""
    with open(HOSTS_FILE, "r") as f:
        return f.read()


def parse_hosts_file(content: str) -> Tuple[str, list[str], str]:
    """Parse hosts file into sections: before, blocked domains, after.

    Returns:
        Tuple of (before_section, blocked_domains, after_section)
    """
    lines = content.splitlines()
    before_lines = []
    blocked_domains = []
    after_lines = []

    in_blocker_section = False
    found_blocker_section = False

    for line in lines:
        if line.strip() == BEGIN_MARKER:
            in_blocker_section = True
            found_blocker_section = True
            continue
        elif line.strip() == END_MARKER:
            in_blocker_section = False
            continue

        if in_blocker_section:
            # Extract domain from blocked entry (format: 127.0.0.1 domain.com)
            parts = line.split()
            if len(parts) >= 2 and parts[0] == "127.0.0.1":
                blocked_domains.append(parts[1])
        elif found_blocker_section:
            after_lines.append(line)
        else:
            before_lines.append(line)

    return "\n".join(before_lines), blocked_domains, "\n".join(after_lines)


def verify_critical_entries(content: str) -> Tuple[bool, str]:
    """Verify that all critical /etc/hosts entries exist.

    Returns:
        Tuple of (is_valid, error_message)
    """
    lines = content.splitlines()
    for pattern in CRITICAL_PATTERNS:
        regex = re.compile(pattern, re.MULTILINE)
        found = False
        for line in lines:
            if regex.match(line):
                found = True
                break
        if not found:
            return False, f"Critical entry missing for pattern: {pattern}"
    return True, ""


def build_hosts_content(before: str, blocked_domains: list[str], after: str) -> str:
    """Build the complete hosts file content from sections."""
    parts = [before]

    if blocked_domains:
        blocker_section = [BEGIN_MARKER]
        for domain in blocked_domains:
            blocker_section.append(f"127.0.0.1 {domain}")
        blocker_section.append(END_MARKER)
        parts.append("\n".join(blocker_section))

    if after:
        parts.append(after)

    # Join with newlines, ensuring no double newlines
    content = "\n".join(parts)
    # Ensure file ends with newline
    if not content.endswith("\n"):
        content += "\n"
    return content


def flush_dns_cache() -> None:
    """Flush macOS DNS cache to make /etc/hosts changes take effect immediately."""
    subprocess.run(
        ["sudo", "dscacheutil", "-flushcache"],
        capture_output=True,
    )
    subprocess.run(
        ["sudo", "killall", "-HUP", "mDNSResponder"],
        capture_output=True,
    )


def write_hosts_file(content: str) -> Tuple[bool, str]:
    """Write content to /etc/hosts using sudo.

    Returns:
        Tuple of (success, error_message)
    """
    # Verify critical entries before writing
    is_valid, error = verify_critical_entries(content)
    if not is_valid:
        return False, f"Critical entries missing. Edit cancelled. {error}"

    # Write to temp file first
    with tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".hosts") as f:
        f.write(content)
        temp_path = f.name

    try:
        # Use sudo cp to copy to /etc/hosts
        result = subprocess.run(
            ["sudo", "cp", temp_path, HOSTS_FILE],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            return False, f"Failed to write hosts file: {result.stderr}"

        # Verify after write
        new_content = read_hosts_file()
        is_valid, error = verify_critical_entries(new_content)
        if not is_valid:
            return False, f"Verification failed after write. {error}"

        # Flush DNS cache to make changes take effect immediately
        flush_dns_cache()

        return True, ""
    finally:
        # Clean up temp file
        subprocess.run(["rm", "-f", temp_path], capture_output=True)


def block_domain(domain: str) -> Tuple[bool, str]:
    """Block a domain (both apex and www variants).

    Returns:
        Tuple of (success, message)
    """
    domains = normalize_domain(domain)
    content = read_hosts_file()
    before, blocked, after = parse_hosts_file(content)

    # Add domains if not already blocked
    added = []
    for d in domains:
        if d not in blocked:
            blocked.append(d)
            added.append(d)

    if not added:
        return True, f"Domain(s) already blocked: {', '.join(domains)}"

    new_content = build_hosts_content(before, blocked, after)
    success, error = write_hosts_file(new_content)

    if success:
        return True, f"Successfully blocked: {', '.join(added)}"
    else:
        return False, error


def unblock_domain(domain: str) -> Tuple[bool, str]:
    """Unblock a domain (both apex and www variants).

    Returns:
        Tuple of (success, message)
    """
    domains = normalize_domain(domain)
    content = read_hosts_file()
    before, blocked, after = parse_hosts_file(content)

    # Remove domains if blocked
    removed = []
    for d in domains:
        if d in blocked:
            blocked.remove(d)
            removed.append(d)

    if not removed:
        return True, f"Domain(s) not blocked: {', '.join(domains)}"

    new_content = build_hosts_content(before, blocked, after)
    success, error = write_hosts_file(new_content)

    if success:
        return True, f"Successfully unblocked: {', '.join(removed)}"
    else:
        return False, error


def get_blocked_domains() -> list[str]:
    """Get list of currently blocked domains."""
    content = read_hosts_file()
    _, blocked, _ = parse_hosts_file(content)
    return blocked

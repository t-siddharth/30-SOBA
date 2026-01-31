"""Website Blocker Agent using CloudConnexa VPN and OpenAI Agents SDK.

This agent blocks websites via DNS filtering through CloudConnexa's Cyber Shield
feature, which applies to all devices connected to the VPN.

Environment Variables Required:
    CLOUDCONNEXA_CLIENT_ID: OAuth2 client ID from CloudConnexa admin portal
    CLOUDCONNEXA_CLIENT_SECRET: OAuth2 client secret
    CLOUDCONNEXA_REGION: API region (default: "api.openvpn.com")
"""

import asyncio

from agents import Agent, Runner, function_tool

from . import cloudconnexa_manager


@function_tool
def block_website(domain: str) -> str:
    """Block a website via CloudConnexa Cyber Shield DNS filtering.

    This blocks both the apex domain (example.com) and www variant (www.example.com)
    for all devices connected to the VPN.

    Args:
        domain: The domain to block (e.g., "facebook.com" or "www.twitter.com")

    Returns:
        A message indicating success or failure.
    """
    success, message = cloudconnexa_manager.block_domain(domain)
    return message


@function_tool
def unblock_website(domain: str) -> str:
    """Unblock a website from CloudConnexa Cyber Shield DNS filtering.

    This unblocks both the apex domain (example.com) and www variant (www.example.com)
    for all devices connected to the VPN.

    Args:
        domain: The domain to unblock (e.g., "facebook.com" or "www.twitter.com")

    Returns:
        A message indicating success or failure.
    """
    success, message = cloudconnexa_manager.unblock_domain(domain)
    return message


@function_tool
def list_blocked_websites() -> str:
    """List all currently blocked websites in CloudConnexa Cyber Shield.

    Returns:
        A formatted list of blocked domains, or a message if none are blocked.
    """
    success, blocked, error = cloudconnexa_manager.get_blocked_domains()
    if not success:
        return f"Failed to retrieve blocked websites: {error}"
    if not blocked:
        return "No websites are currently blocked."
    return "Currently blocked websites:\n" + "\n".join(f"  - {d}" for d in blocked)


@function_tool
def check_vpn_connection() -> str:
    """Check if the CloudConnexa API connection is working.

    Returns:
        A message indicating the connection status.
    """
    success, message = cloudconnexa_manager.verify_connection()
    return message


agent = Agent(
    name="VPN Website Blocker",
    instructions="""You are a helpful assistant that manages website blocking via CloudConnexa VPN.

You can help users:
- Block websites to improve focus and productivity across ALL their VPN-connected devices
- Unblock websites when needed
- View the list of currently blocked websites
- Check the VPN API connection status

When blocking or unblocking websites, explain that:
1. Changes apply to ALL devices connected to the CloudConnexa VPN
2. Blocking works via DNS filtering (Cyber Shield) - blocked domains won't resolve
3. Changes may take a few moments to propagate to all connected devices
4. Users must be connected to the VPN for blocking to take effect

Always confirm actions with the user before making changes.
Be helpful and supportive about productivity goals while respecting the user's autonomy.""",
    tools=[block_website, unblock_website, list_blocked_websites, check_vpn_connection],
)


async def main():
    """Run the interactive CLI loop."""
    print("CloudConnexa VPN Website Blocker Agent")
    print("=" * 45)
    print(
        "I can help you block distracting websites across all your VPN-connected devices."
    )
    print("Type 'quit' or 'exit' to stop.\n")

    # Check connection on startup
    success, message = cloudconnexa_manager.verify_connection()
    if success:
        print("[Connected to CloudConnexa]\n")
    else:
        print(f"[Warning: {message}]\n")
        print("Set CLOUDCONNEXA_CLIENT_ID and CLOUDCONNEXA_CLIENT_SECRET to connect.\n")

    conversation_history = []

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye!")
            break

        if not user_input:
            continue

        if user_input.lower() in ("quit", "exit"):
            print("Goodbye!")
            break

        conversation_history.append({"role": "user", "content": user_input})
        result = await Runner.run(agent, conversation_history)
        conversation_history = result.to_input_list()
        print(f"\nAssistant: {result.final_output}\n")


if __name__ == "__main__":
    asyncio.run(main())

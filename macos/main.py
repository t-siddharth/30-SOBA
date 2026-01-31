"""Website Blocker Agent using OpenAI Agents SDK."""

import asyncio

from agents import Agent, Runner, function_tool

from . import hosts_manager


@function_tool
def block_website(domain: str) -> str:
    """Block a website by adding it to /etc/hosts.

    This blocks both the apex domain (example.com) and www variant (www.example.com).

    Args:
        domain: The domain to block (e.g., "facebook.com" or "www.twitter.com")

    Returns:
        A message indicating success or failure.
    """
    success, message = hosts_manager.block_domain(domain)
    return message


@function_tool
def unblock_website(domain: str) -> str:
    """Unblock a website by removing it from /etc/hosts.

    This unblocks both the apex domain (example.com) and www variant (www.example.com).

    Args:
        domain: The domain to unblock (e.g., "facebook.com" or "www.twitter.com")

    Returns:
        A message indicating success or failure.
    """
    success, message = hosts_manager.unblock_domain(domain)
    return message


@function_tool
def list_blocked_websites() -> str:
    """List all currently blocked websites.

    Returns:
        A formatted list of blocked domains, or a message if none are blocked.
    """
    blocked = hosts_manager.get_blocked_domains()
    if not blocked:
        return "No websites are currently blocked."
    return "Currently blocked websites:\n" + "\n".join(f"  - {d}" for d in blocked)


agent = Agent(
    name="Website Blocker",
    instructions="""You are a helpful assistant that manages website blocking on macOS.

You can help users:
- Block websites to improve focus and productivity
- Unblock websites when needed
- View the list of currently blocked websites

When blocking or unblocking websites, always confirm the action with the user first.
Explain that blocking works by modifying the /etc/hosts file and requires sudo access.

Be helpful and supportive about productivity goals while respecting the user's autonomy.""",
    tools=[block_website, unblock_website, list_blocked_websites],
)


async def main():
    """Run the interactive CLI loop."""
    print("Website Blocker Agent")
    print("=" * 40)
    print("I can help you block distracting websites.")
    print("Type 'quit' or 'exit' to stop.\n")

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

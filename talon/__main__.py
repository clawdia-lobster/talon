"""
Entry point for talon — interactive REPL or non-interactive CLI.
"""

import sys

import click

import talon


@click.command(context_settings={"help_option_names": ["-h", "--help"]})
@click.version_option(version=talon.__version__, prog_name="talon")
@click.option("-c", "--command", metavar="MSG", help="Send MSG as a single message and exit.")
@click.option("--stdin", "stdin_mode", is_flag=True, help="Read message from stdin, send, and exit.")
@click.option("--json", "json_mode", is_flag=True, help="Output response as JSON (implies --quiet).")
@click.option("--quiet", is_flag=True, help="Suppress streaming; print only final response text.")
@click.option("--session", metavar="KEY", help="Pin to a named session key (persists across invocations).")
@click.option("--agent", metavar="NAME", help="Override the agent (default: from config).")
@click.option("--model", metavar="PROVIDER/MODEL", help="Override the model (default: from config).")
@click.option("--url", metavar="URL", help="Override the Gateway URL (default: from config).")
@click.option("--token", metavar="TOKEN", help="Override the auth token (default: from config).")
@click.option("--no-stream", is_flag=True, help="Disable streaming in interactive mode (wait for full response).")
def main(command, stdin_mode, json_mode, quiet, session, agent, model, url, token, no_stream):
    """
    Talon — a minimal terminal client for OpenClaw's OpenResponses API.

    Run without arguments for an interactive REPL session.
    Use -c or --stdin for non-interactive one-shot queries.
    """
    import talon.state as state

    # Apply overrides from CLI to state
    if agent:
        state.agent = agent
    if model:
        state.model = model
    if url:
        state.gateway_url = url
    if token:
        state.token = token
    if session:
        state.session = session

    # Determine mode
    noninteractive = command or stdin_mode

    # Validate mutual exclusion
    if command and stdin_mode:
        click.echo("talon: error: --command and --stdin are mutually exclusive", err=True)
        sys.exit(1)

    # Validate non-empty input
    if command is not None and not command.strip():
        click.echo("talon: error: --command requires a non-empty message", err=True)
        sys.exit(1)

    if noninteractive:
        # Read message
        if stdin_mode:
            message = sys.stdin.read()
            if not message.strip():
                click.echo("talon: error: stdin is empty", err=True)
                sys.exit(1)
        else:
            message = command

        # Build args namespace for cli.run
        class Args:
            pass
        args = Args()
        args.message = message
        args.json = json_mode
        args.quiet = quiet or json_mode  # --json implies --quiet
        args.session = session

        import talon.cli as cli
        cli.run(args)
    else:
        # Interactive REPL
        import talon.repl as repl
        repl.run()


def run():
    """Entry point for console script."""
    main()


if __name__ == "__main__":
    main()

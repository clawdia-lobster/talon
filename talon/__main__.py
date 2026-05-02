import hy
import sys


def run():
    "Run the talon client."
    import talon.client.repl
    talon.client.repl.run()


if __name__ == '__main__':
    run()

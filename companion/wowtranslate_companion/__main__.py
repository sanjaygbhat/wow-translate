"""Start the companion:  python -m wowtranslate_companion  [--demo] [--config PATH]"""

import argparse

from . import __version__


def main() -> None:
    parser = argparse.ArgumentParser(prog="WoWTranslateCompanion", description="WoW Translate Companion " + __version__)
    parser.add_argument("--demo", action="store_true", help="show sample chat without the game (to try your translation service)")
    parser.add_argument("--config", default="", help="use a different settings file")
    args = parser.parse_args()
    from .app import run
    run(demo=args.demo, config_path=args.config)


if __name__ == "__main__":
    main()

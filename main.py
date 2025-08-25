import importlib
import sys
from pathlib import Path

from dotenv import load_dotenv

if __name__ == "__main__":
    load_dotenv()
    location = Path(__file__).parent / "functions"
    sys.path.insert(0, str(location))

    func, *args = sys.argv[1:]
    mod = importlib.import_module(name=f"{func}.main")
    run = getattr(mod, "main")
    run(*args)

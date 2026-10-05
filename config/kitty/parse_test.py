import sys
sys.path.insert(0, '/Applications/kitty.app/Contents/Resources/Python/lib/kitty-extensions/python-lib.bypy.frozen')
from kitty.config import load_config
try:
    load_config("kitty.conf")
    print("Success")
except Exception as e:
    import traceback
    traceback.print_exc()

import plistlib, json, os
p = os.path.expanduser("~/Library/Preferences/com.googlecode.iterm2.plist")
o = os.path.expanduser("~/.config/iterm2-sync/iterm2/iterm2-settings.json")
with open(p, "rb") as f: data = plistlib.load(f)
class E(json.JSONEncoder):
    def default(self, x):
        if isinstance(x, bytes): return x.hex()
        if hasattr(x, "isoformat"): return x.isoformat()
        return str(x)
with open(o, "w") as f: json.dump(data, f, indent=2, cls=E)
print("✅ Готово:", o)

"""Collects creature facts from Petopia Forever (names, levels, zones, looks).

Only factual fields are read; no images or descriptive text are copied.
"""
import hashlib, os, time, urllib.request

BASE = "https://www.wow-petopia.com/forever/"


class Fetcher:
    """HTTP GET with an on-disk cache and a delay between real requests."""

    def __init__(self, cache_dir, delay=1.5):
        self.cache_dir, self.delay = cache_dir, delay
        os.makedirs(cache_dir, exist_ok=True)

    def get(self, url):
        path = os.path.join(self.cache_dir, hashlib.sha1(url.encode()).hexdigest() + ".html")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                return f.read()
        time.sleep(self.delay)
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                html = r.read().decode("utf-8", "replace")
        except Exception as e:
            raise RuntimeError("fetch failed for %s: %s" % (url, e)) from e
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        return html

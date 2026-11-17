import os, tempfile, unittest

try:
    from PIL import Image
    from tools import make_skin
except ImportError:  # Pillow only exists in .cache/venv
    Image = None


@unittest.skipUnless(Image, "Pillow not installed in this interpreter")
class MakeSkinTest(unittest.TestCase):
    def sample(self):
        img = Image.new("RGB", (200, 100), (255, 0, 255))        # magenta surround
        for x in range(50, 150):
            for y in range(25, 75):
                img.putpixel((x, y), (40, 90, 50))                # green art
        img.putpixel((60, 30), (255, 255, 255))                   # white highlight inside the art
        img.putpixel((61, 30), (120, 70, 40))                     # brown
        img.putpixel((0, 0), (250, 8, 246))                       # JPEG-ish near-magenta
        path = os.path.join(tempfile.mkdtemp(), "in.png")
        img.save(path)
        return path

    def test_magenta_becomes_transparent_and_art_stays(self):
        canvas, w, h = make_skin.build(self.sample(), 100)
        self.assertEqual((w, h), (100, 50))
        self.assertEqual(canvas.size, (128, 64))                  # padded to powers of two
        self.assertEqual(canvas.getpixel((2, 2))[3], 0)           # magenta gone
        self.assertEqual(canvas.getpixel((0, 0))[3], 0)           # near-magenta gone too
        r, g, b, a = canvas.getpixel((50, 25))
        self.assertEqual(a, 255)                                  # art opaque
        self.assertTrue(g > r and g > b)                          # and still green
        self.assertEqual(canvas.getpixel((110, 60))[3], 0)        # padding is transparent

    def test_white_and_brown_are_not_keyed(self):
        keyed = make_skin.key_magenta(Image.open(self.sample()))
        self.assertEqual(keyed.getpixel((60, 30)), (255, 255, 255, 255))
        self.assertEqual(keyed.getpixel((61, 30)), (120, 70, 40, 255))

    def test_keep_background(self):
        canvas, _, _ = make_skin.build(self.sample(), 100, keep_background=True)
        self.assertEqual(canvas.getpixel((2, 2))[3], 255)

    def test_tga_roundtrip(self):
        canvas, _, _ = make_skin.build(self.sample(), 100)
        path = os.path.join(tempfile.mkdtemp(), "out.tga")
        canvas.save(path, format="TGA", compression=None)
        back = Image.open(path)
        self.assertEqual((back.mode, back.size), ("RGBA", (128, 64)))
        self.assertEqual(back.getpixel((2, 2))[3], 0)

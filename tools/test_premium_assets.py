"""Validate optional premium building sprites without requiring them for clean clones.

Run: python3 -m unittest tools.test_premium_assets -v
The test verifies project paths and only checks the PNGs when installed.
"""
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
BUILDINGS = ROOT / "assets" / "premium" / "buildings"
REQUIRED = ("safehouse", "hospital", "barracks", "garage",
            "intel_office", "scrapyard", "data_hub")
OPTIONAL = ("vault",)
SIGNATURE = b"\x89PNG\r\n\x1a\n"


class PremiumArtTests(unittest.TestCase):
    def test_loader_and_scene_contracts(self):
        building = (ROOT / "scripts/buildings/Building.gd").read_text()
        lot = (ROOT / "scripts/buildings/BuildLot.gd").read_text()
        self.assertIn("assets/premium/buildings/%s.png", building)
        self.assertIn("assets/premium/buildings/%s.png", lot)
        self.assertIn("ResourceLoader.exists", building)
        self.assertIn("ResourceLoader.exists", lot)

    def test_asset_pack_if_installed(self):
        installed = [BUILDINGS / (name + ".png") for name in REQUIRED + OPTIONAL
                     if (BUILDINGS / (name + ".png")).exists()]
        if not installed:
            self.fail("Premium building sprites must be present in the game repository")
        for name in REQUIRED:
            self.assertTrue((BUILDINGS / (name + ".png")).is_file(),
                            f"Missing premium sprite: {name}.png")
        for path in installed:
            with self.subTest(path=path.name):
                data = path.read_bytes()
                self.assertGreater(len(data), 1024)
                self.assertEqual(data[:8], SIGNATURE)
                width, height = struct.unpack(">II", data[16:24])
                self.assertEqual((width, height), (768, 768))
                # PNG color type 6 = RGBA, 8 bits/channel
                self.assertEqual(data[24], 8)
                self.assertEqual(data[25], 6)


if __name__ == "__main__":
    unittest.main()

import importlib.util
import unittest
from pathlib import Path
from unittest import mock


SPEC = importlib.util.spec_from_file_location("pixel_buds", Path(__file__).parents[1] / "pixel_buds.py")
pixel_buds = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pixel_buds)


class PixelBudsTest(unittest.TestCase):
    def test_parses_separate_battery_levels_and_unknown_case(self):
        self.assertEqual(
            pixel_buds.battery(
                "case: unknown\nleft bud: 96% (not charging)\nright bud: 93% (not charging)"
            ),
            {"left": 96, "right": 93, "case": None},
        )

    def test_prefers_cargo_install_for_latest_device_support(self):
        with mock.patch.object(pixel_buds.Path, "home", return_value=Path("/home/test")), \
             mock.patch.object(pixel_buds.Path, "is_file", return_value=True), \
             mock.patch.object(pixel_buds.os, "access", return_value=True):
            self.assertEqual(pixel_buds.pbpctrl(), "/home/test/.cargo/bin/pbpctrl")

    def test_validates_equalizer_bands(self):
        self.assertEqual(pixel_buds.equalizer(["-6", "-1.5", "0", "2", "6"]), [-6, -1.5, 0, 2, 6])
        self.assertIsNone(pixel_buds.equalizer([0, 0, 0, 0, 7]))

if __name__ == "__main__":
    unittest.main()

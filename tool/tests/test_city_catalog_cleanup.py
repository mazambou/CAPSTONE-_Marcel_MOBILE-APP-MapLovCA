import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))

from generate_city_catalog_cleanup import (  # noqa: E402
    CERTAIN_PARENT_CITY_GEONAMES,
    CitySource,
    classification,
)


def city(feature_code: str, geoname_id: int = 1) -> CitySource:
    return CitySource("CA", "08", "Test", geoname_id, "P", feature_code)


class CityClassificationTest(unittest.TestCase):
    def test_rejects_sections_localities_villages_and_settlements(self):
        for code in ("PPLX", "PPLL", "PPLF", "PPLS", "STLMT"):
            with self.subTest(code=code):
                self.assertEqual(
                    classification(city(code), {"CA": set()})[0], "excluded"
                )

    def test_generic_populated_place_requires_positive_city_evidence(self):
        self.assertEqual(
            classification(city("PPL", 5969782), {"CA": set()})[0],
            "manual_review",
        )
        self.assertEqual(
            classification(city("PPL", 5969782), {"CA": {5969782}})[0],
            "verified_city",
        )

    def test_national_capital_is_inherently_accepted(self):
        self.assertEqual(
            classification(city("PPLC", 6094817), {"CA": set()})[0],
            "verified_city",
        )

    def test_certain_toronto_parent_mappings_are_stable_ids(self):
        self.assertEqual(CERTAIN_PARENT_CITY_GEONAMES[7871312], 6167865)
        self.assertEqual(CERTAIN_PARENT_CITY_GEONAMES[5950268], 6167865)


if __name__ == "__main__":
    unittest.main()

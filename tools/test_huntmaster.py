import os, unittest
from tools import huntmaster

FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "huntmaster_sample.lua")


class HuntmasterTest(unittest.TestCase):
    def setUp(self):
        self.data = huntmaster.load(FIXTURE)

    def test_forest_spider(self):
        c = self.data[30]
        self.assertEqual((c["name"], c["family"], c["min"], c["max"]),
                         ("Forest Spider", "spider", 5, 6))
        self.assertEqual((c["map"], c["area"], c["cls"]), (1429, 12, None))
        self.assertEqual(c["coords"][0], (28.4, 66.4))
        self.assertEqual(c["diet"], "Meat")

    def test_missing_fields(self):
        c = self.data[999001]
        self.assertIsNone(c["family"])
        self.assertIsNone(c["map"])
        self.assertEqual(c["coords"], [])
        self.assertEqual((c["min"], c["max"]), (42, 42))
        self.assertEqual(c["name"], 'Quote "Test" Beast')

    def test_rare_elite(self):
        self.assertEqual(self.data[2931]["cls"], "rareelite")

    def test_classification(self):
        self.assertEqual(huntmaster.parse_cls("Rare Elite"), "rareelite")
        self.assertEqual(huntmaster.parse_cls("Rare"), "rare")
        self.assertEqual(huntmaster.parse_cls("Elite"), "elite")
        self.assertIsNone(huntmaster.parse_cls(None))

    def test_project_conditional_takes_non_classic_branch(self):
        text = 'A.T = { ["k"] = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and "50" or "41" }'
        self.assertEqual(huntmaster.read_lua_tables(text)["T"], {"k": "41"})

    def test_family_slugs(self):
        self.assertEqual(huntmaster.FAMILY_SLUG["Birds of Prey"], "birdofprey")
        self.assertEqual(huntmaster.FAMILY_SLUG["Carrion Bird"], "carrionbird")
        self.assertEqual(huntmaster.FAMILY_SLUG["Wind Serpent"], "windserpent")






class LevelsTest(unittest.TestCase):
    def test_levels(self):
        self.assertEqual(huntmaster.parse_levels("5-6"), (5, 6))
        self.assertEqual(huntmaster.parse_levels("42"), (42, 42))
        self.assertEqual(huntmaster.parse_levels("??"), (None, None))
        self.assertEqual(huntmaster.parse_levels(None), (None, None))

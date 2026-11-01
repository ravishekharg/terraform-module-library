"""Unit tests for semver_check.py (standard library only):  python -m unittest discover -s scripts"""
import copy
import unittest

from semver_check import bump, diff, is_enough

BASE = {
    "inputs": [
        {"name": "name", "type": "string", "required": True, "default": None, "description": "Name prefix."},
        {"name": "cidr", "type": "string", "required": False, "default": "10.0.0.0/16", "description": "VPC CIDR."},
        {"name": "nat_mode", "type": "string", "required": False, "default": "single", "description": "NAT."},
    ],
    "outputs": [{"name": "vpc_id"}, {"name": "private_subnet_ids"}],
    "resources": [{"type": "aws_vpc", "name": "this", "mode": "managed"},
                  {"type": "aws_subnet", "name": "private", "mode": "managed"},
                  {"type": "aws_availability_zones", "name": "available", "mode": "data"}],
    "requirements": [{"name": "terraform", "version": ">= 1.9"}, {"name": "aws", "version": ">= 5.40"}],
    "moved": {},
}


def changed(fn):
    head = copy.deepcopy(BASE)
    fn(head)
    return diff(BASE, head)


def inp(doc, name):
    return next(i for i in doc["inputs"] if i["name"] == name)


class Diff(unittest.TestCase):
    def test_no_change(self):
        self.assertEqual(diff(BASE, copy.deepcopy(BASE)), ("none", []))

    def test_description_only_is_patch(self):
        level, reasons = changed(lambda h: inp(h, "cidr").update(description="The VPC's CIDR block."))
        self.assertEqual(level, "patch")
        self.assertIn("description", reasons[0][1])

    def test_new_optional_input_and_output_are_minor(self):
        def f(h):
            h["inputs"].append({"name": "tags", "type": "map(string)", "required": False, "default": {}})
            h["outputs"].append({"name": "nat_ids"})
        self.assertEqual(changed(f)[0], "minor")

    def test_breaking_changes_are_major(self):
        cases = {
            "input removed": lambda h: h["inputs"].remove(inp(h, "nat_mode")),
            "new required input": lambda h: h["inputs"].append({"name": "env", "type": "string", "required": True}),
            "input now required": lambda h: inp(h, "cidr").update(required=True, default=None),
            "type changed": lambda h: inp(h, "cidr").update(type="list(string)"),
            "default changed": lambda h: inp(h, "nat_mode").update(default="per_az"),
            "output removed": lambda h: h["outputs"].pop(),
            "resource renamed without moved": lambda h: h["resources"][1].update(name="app"),
            "provider minimum raised": lambda h: h["requirements"][1].update(version=">= 6.0"),
            "terraform minimum raised": lambda h: h["requirements"][0].update(version=">= 1.10"),
        }
        for label, fn in cases.items():
            with self.subTest(label):
                level, reasons = changed(fn)
                self.assertEqual(level, "major", reasons)

    def test_rename_with_moved_block_is_not_breaking(self):
        def f(h):
            h["resources"][1]["name"] = "app"
            h["moved"] = {"aws_subnet.private": "aws_subnet.app"}
        level, reasons = changed(f)
        self.assertEqual(level, "patch", reasons)

    def test_output_description_is_patch(self):
        self.assertEqual(changed(lambda h: h["outputs"][0].update(description="The VPC id."))[0], "patch")

    def test_terraform_docs_type_without_provider_prefix_still_matches_moved_blocks(self):
        def strip(doc):
            for r in doc["resources"]:
                r["provider"], r["type"] = "aws", r["type"].removeprefix("aws_")
        base, head = copy.deepcopy(BASE), copy.deepcopy(BASE)
        strip(base)
        strip(head)
        head["resources"][1]["name"] = "app"
        head["moved"] = {"aws_subnet.private": "aws_subnet.app"}       # moved blocks use the full type
        self.assertEqual(diff(base, head)[0], "patch")

    def test_data_sources_and_whitespace_in_types_are_ignored(self):
        def f(h):
            h["resources"].pop()                                  # a data source: no state to destroy
            inp(h, "cidr")["type"] = " string "
        self.assertEqual(changed(f)[0], "none")

    def test_reasons_are_sorted_most_severe_first(self):
        def f(h):
            h["outputs"].append({"name": "x"})
            h["outputs"].remove({"name": "vpc_id"})
        _, reasons = changed(f)
        self.assertEqual(reasons[0][0], "major")


class Versions(unittest.TestCase):
    def test_bump(self):
        self.assertEqual(bump("1.4.2", "major"), "2.0.0")
        self.assertEqual(bump("1.4.2", "minor"), "1.5.0")
        self.assertEqual(bump("1.4.2", "patch"), "1.4.3")

    def test_is_enough(self):
        self.assertTrue(is_enough("1.4.2", "2.0.0", "major"))
        self.assertFalse(is_enough("1.4.2", "1.5.0", "major"))   # a breaking change shipped as a minor
        self.assertTrue(is_enough("1.4.2", "1.5.0", "minor"))
        self.assertTrue(is_enough("1.4.2", "2.0.0", "patch"))    # bigger than needed is allowed
        self.assertFalse(is_enough("1.4.2", "1.4.2", "none"))    # must be newer
        self.assertTrue(is_enough("0.3.0", "0.3.1", "major"))    # before 1.0.0 nothing is promised


if __name__ == "__main__":
    unittest.main()

import importlib.util
from pathlib import Path
import re
import os
import json
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "scripts" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VerificationTests(unittest.TestCase):
    def test_pin_accepts_original_and_module_state(self):
        pin = load("pin_deployed_ami").deployed_ami
        resource = {"mode": "managed", "type": "aws_instance", "name": "web_server",
                    "instances": [{"attributes": {"ami": "ami-0123456789abcdef0"}}]}
        self.assertEqual(pin({"resources": [resource]}), "ami-0123456789abcdef0")
        resource["module"] = "module.compute"
        self.assertEqual(pin({"resources": [resource]}), "ami-0123456789abcdef0")
        with self.assertRaises(ValueError):
            pin({"resources": [resource, resource]})
        with self.assertRaises(ValueError):
            pin({"resources": []})

    def test_guard_rejects_replacement_creation_and_unrelated_updates(self):
        guard = load("check_plan").check_plan
        def plan(actions, before=None, after=None, address="module.networking.aws_vpc.app_vpc"):
            return {"resource_changes": [{"mode": "managed", "address": address,
                     "change": {"actions": actions, "before": before, "after": after}}]}
        with self.assertRaises(ValueError):
            guard(plan(["delete", "create"]))
        with self.assertRaises(ValueError):
            guard(plan(["create"]), "module.networking.aws_vpc.app_vpc")
        with self.assertRaises(ValueError):
            guard(plan(["update"], {"cidr_block": "10.0.0.0/16"}, {"cidr_block": "10.10.0.0/16"}), "module.networking.aws_vpc.app_vpc")
        with self.assertRaises(ValueError):
            guard(plan(["update"], {}, {}, "module.compute.aws_instance.web_server"), "module.networking.aws_vpc.app_vpc")
        guard(plan(["update"], {"tags": {"Name": "drift"}}, {"tags": {"Name": "demo"}}), "module.networking.aws_vpc.app_vpc")

    def test_backend_initialization_preserves_selected_lock_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "terraform"
            fake.write_text('#!/usr/bin/env python3\nimport json,os,sys\nopen(os.environ["CAPTURE"],"w").write(json.dumps(sys.argv[1:]))\n')
            fake.chmod(0o755)
            captured = Path(directory) / "args.json"
            env = dict(os.environ, PATH=directory + os.pathsep + os.environ["PATH"],
                       CAPTURE=str(captured), TF_STATE_BUCKET="test-bucket", TF_STATE_KEY="devops/terraform.tfstate",
                       AWS_REGION="ap-south-1", TF_LOCK_TABLE="test-locks")
            for mode in ["dynamodb", "dual", "s3"]:
                env["TF_LOCK_MODE"] = mode
                result = subprocess.run(["bash", str(ROOT / "scripts/init_backend.sh")], env=env, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                args = json.loads(captured.read_text())
                self.assertIn("-backend-config=key=devops/terraform.tfstate", args)
                self.assertEqual("-backend-config=dynamodb_table=test-locks" in args, mode != "s3")
                self.assertIn("-backend-config=use_lockfile=" + ("false" if mode == "dynamodb" else "true"), args)
            captured.unlink()
            env["TF_LOCK_MODE"] = "invalid"
            result = subprocess.run(["bash", str(ROOT / "scripts/init_backend.sh")], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(captured.exists())

    def test_all_original_addresses_have_unique_migrations(self):
        moves = dict(re.findall(r"moved\s*\{\s*from\s*=\s*(\S+)\s+to\s*=\s*(\S+)\s*\}", (ROOT / "main.tf").read_text()))
        names = {"aws_vpc.app_vpc": "networking", "aws_subnet.public_subnet": "networking",
                 "aws_internet_gateway.igw": "networking", "aws_route_table.public_rt": "networking",
                 "aws_route_table_association.rta": "networking", "aws_security_group.web_sg": "compute",
                 "aws_instance.web_server": "compute"}
        self.assertEqual(moves, {address: f"module.{module}.{address}" for address, module in names.items()})
        self.assertEqual(len(set(moves.values())), 7)


if __name__ == "__main__":
    unittest.main()

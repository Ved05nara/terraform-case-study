#!/usr/bin/env python3
"""Read current Terraform state and save only its EC2 AMI to an ignored local file."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def deployed_ami(state):
    instances = [i for r in state.get("resources", [])
                 if r.get("mode") == "managed" and r.get("type") == "aws_instance"
                 and r.get("name") == "web_server" for i in r.get("instances", [])]
    if len(instances) != 1:
        raise ValueError("Expected exactly one managed web_server in the selected workspace; check the backend/workspace.")
    ami = instances[0].get("attributes", {}).get("ami", "")
    if not re.fullmatch(r"ami-(?:[0-9a-f]{8}|[0-9a-f]{17})", ami):
        raise ValueError("State did not contain a valid EC2 AMI ID.")
    return ami


def main():
    destination = Path("deployment.auto.tfvars")
    if destination.exists():
        sys.exit("deployment.auto.tfvars already exists; review it rather than overwriting it.")
    if not Path("backend.tf").exists():
        sys.exit("Run this from the initialized project root.")
    result = subprocess.run(["terraform", "state", "pull"], check=True, capture_output=True, text=True)
    ami = deployed_ami(json.loads(result.stdout))
    # Exclusive creation avoids overwriting another user's local settings.
    with destination.open("x", encoding="utf-8") as stream:
        stream.write(f'ami_id = "{ami}"\nallow_latest_ami = false\n')
    os.chmod(destination, 0o600)
    print(f"Pinned {ami} in deployment.auto.tfvars. No AWS resources or remote state were changed.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"AMI pinning failed: {error}")

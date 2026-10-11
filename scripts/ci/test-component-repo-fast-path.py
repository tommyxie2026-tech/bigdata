#!/usr/bin/env python3
"""Contract tests for the component RPM repository idempotency guard."""

from __future__ import annotations

import gzip
import hashlib
import json
import os
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / "scripts/ci/check-component-repo-fast-path.py"
STAGER = ROOT / "scripts/ci/stage-tested-rpms.sh"
COMPONENTS = ROOT / "ci/components.yaml"
COMPONENT_WORKFLOW = ROOT / ".github/workflows/build-components.yml"
CHECK_WORKFLOW = ROOT / ".github/workflows/check-component-repo.yml"
COMPONENT = "tez"
VERSION = "0.10.5"
RPM_NAME = "tez-0.10.5-1.noarch.rpm"
RPM_BYTES = b"fake rpm payload for contract testing"
RPM_SHA = hashlib.sha256(RPM_BYTES).hexdigest()


def tag(name: str) -> str:
    return f"{{http://linux.duke.edu/metadata/{'common' if name not in {'data', 'repomd'} else 'repo'}}}{name}"


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_fixture(root: Path) -> Path:
    repo = root / "repo"
    target = repo / "repo/openeuler-22.03-lts-sp4/bigtop-3.6/tez/0.10.5"
    repodata = target / "repodata"
    repodata.mkdir(parents=True)

    rpm_pointer = (
        "version https://git-lfs.github.com/spec/v1\n"
        f"oid sha256:{RPM_SHA}\n"
        f"size {len(RPM_BYTES)}\n"
    ).encode()
    (target / RPM_NAME).write_bytes(rpm_pointer)
    (target / "SHA256SUMS").write_text(f"{RPM_SHA}  {RPM_NAME}\n")
    (target / "manifest.yaml").write_text(
        "schema: bigdata.rpm-repo/v1\n"
        "component: tez\n"
        "version: 0.10.5\n"
        "bigtop_version: 3.6.0\n"
        "os: openEuler 22.03 LTS SP4\n"
        "promotion_workflow_commit: " + "a" * 40 + "\n"
        "tested_artifact_run_id: 123456\n"
        "rpm_count: 1\n"
        "test_status: PASS\n"
        "repository_layout: split-runtime/v2\n"
    )

    primary = ET.Element(tag("metadata"), {"packages": "1"})
    package = ET.SubElement(primary, tag("package"), {"type": "rpm"})
    ET.SubElement(package, tag("name")).text = "tez"
    ET.SubElement(package, tag("arch")).text = "noarch"
    version = ET.SubElement(package, tag("version"))
    version.attrib.update(epoch="0", ver="0.10.5", rel="1")
    checksum = ET.SubElement(package, tag("checksum"), {"type": "sha256", "pkgid": "YES"})
    checksum.text = RPM_SHA
    ET.SubElement(package, tag("location"), {"href": RPM_NAME})
    primary_bytes = gzip.compress(ET.tostring(primary, encoding="utf-8"))
    primary_path = repodata / "primary.xml.gz"
    primary_path.write_bytes(primary_bytes)

    repomd = ET.Element(tag("repomd"))
    data = ET.SubElement(repomd, tag("data"), {"type": "primary"})
    ET.SubElement(data, tag("checksum"), {"type": "sha256"}).text = sha(primary_bytes)
    ET.SubElement(data, tag("location"), {"href": "repodata/primary.xml.gz"})
    (repodata / "repomd.xml").write_bytes(ET.tostring(repomd, encoding="utf-8"))
    return repo


class ComponentRepoFastPathTests(unittest.TestCase):
    def run_check(
        self, repo: Path, components_file: Path = COMPONENTS
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "python3",
                str(CHECKER),
                "--component",
                COMPONENT,
                "--version",
                VERSION,
                "--repo-checkout",
                str(repo),
                "--components-file",
                str(components_file),
            ],
            text=True,
            capture_output=True,
            check=False,
        )

    def workflow_jobs(self) -> dict[str, dict[str, object]]:
        result = subprocess.run(
            [
                "ruby",
                "-ryaml",
                "-rjson",
                "-e",
                'workflow = YAML.load_file(ARGV.fetch(0)); puts JSON.generate(workflow.fetch("jobs"))',
                str(COMPONENT_WORKFLOW),
            ],
            text=True,
            capture_output=True,
            check=True,
        )
        return json.loads(result.stdout)

    def test_complete_verified_current_repo_hits_fast_path(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_check(write_fixture(Path(directory)))
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("already current", result.stdout.lower())

    def test_version_mismatch_is_a_safe_build_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = write_fixture(Path(directory))
            manifest = next(repo.rglob("manifest.yaml"))
            manifest.write_text(manifest.read_text().replace("version: 0.10.5", "version: 0.10.4"))
            result = self.run_check(repo)
        self.assertEqual(result.returncode, 1)

    def test_rpm_checksum_mismatch_is_a_safe_build_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = write_fixture(Path(directory))
            target = next(repo.rglob("SHA256SUMS")).parent
            (target / "SHA256SUMS").write_text("0" * 64 + f"  {RPM_NAME}\n")
            result = self.run_check(repo)
        self.assertEqual(result.returncode, 1)

    def test_incomplete_manifest_rpm_set_is_a_safe_build_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = write_fixture(Path(directory))
            (next(repo.rglob("tez-*.rpm"))).unlink()
            result = self.run_check(repo)
        self.assertEqual(result.returncode, 1)

    def test_bad_primary_metadata_is_a_safe_build_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = write_fixture(Path(directory))
            primary = next(repo.rglob("primary.xml.gz"))
            primary.write_bytes(gzip.compress(b"<invalid/>"))
            result = self.run_check(repo)
        self.assertEqual(result.returncode, 1)

    def test_configuration_version_mismatch_is_a_safe_build_fallback(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = write_fixture(Path(directory))
            # Alter the requested version to something other than ci/components.yaml.
            result = subprocess.run(
                [
                    "python3",
                    str(CHECKER),
                    "--component",
                    COMPONENT,
                    "--version",
                    "0.10.4",
                    "--repo-checkout",
                    str(repo),
                    "--components-file",
                    str(COMPONENTS),
                ],
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertEqual(result.returncode, 1)

    def test_runtime_package_set_must_match_configuration_exactly(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = write_fixture(root)
            config = root / "components.yaml"
            config.write_text(
                "components:\n"
                "  tez:\n"
                "    version: 0.10.5\n"
                "    runtime_packages:\n"
                "      - tez\n"
                "      - tez-client\n"
            )
            result = self.run_check(repo, config)
        self.assertEqual(result.returncode, 1)

    def test_pull_requests_check_main_repository_for_fast_path(self) -> None:
        jobs = subprocess.run(
            [
                "ruby",
                "-ryaml",
                "-rjson",
                "-e",
                'workflow = YAML.load_file(ARGV.fetch(0)); puts JSON.generate(workflow.fetch("jobs"))',
                str(CHECK_WORKFLOW),
            ],
            text=True,
            capture_output=True,
            check=True,
        )
        check_steps = json.loads(jobs.stdout)["check"]["steps"]
        repo_checkout = next(step for step in check_steps if step.get("name") == "Checkout repository metadata from main")
        self.assertNotIn("if", repo_checkout)
        verify = next(step for step in check_steps if step.get("id") == "repo")
        self.assertNotIn("EVENT_NAME", verify.get("env", {}))
        command = verify["run"]
        self.assertIn("check-component-repo-fast-path.py", command)
        self.assertNotIn("PR checks always exercise Build and Test", command)
        self.assertNotIn("already_current=false", command.split("python3 scripts/ci/check-component-repo-fast-path.py", 1)[0])

    def test_each_component_uses_repository_gate_and_success_stage_gate(self) -> None:
        jobs = self.workflow_jobs()
        for component in ("zookeeper", "hadoop", "tez", "hive", "spark", "hbase"):
            check = jobs[f"{component}_repo_check"]
            self.assertEqual(check["uses"], "./.github/workflows/check-component-repo.yml")
            build = jobs[f"{component}_build"]
            self.assertEqual(build["needs"], f"{component}_repo_check")
            self.assertIn("outputs.already_current", build["if"])
            self.assertIn("github.event_name != 'pull_request'", jobs[f"{component}_release"]["if"])
            gate = jobs[f"{component}_gate"]
            self.assertIn(f"{component}_repo_check", gate["needs"])
            self.assertIn(f"{component}_build", gate["needs"])
            self.assertIn(f"{component}_test", gate["needs"])
            self.assertIn(f"{component}_release", gate["needs"])
            self.assertEqual(build["uses"], "./.github/workflows/build-one-component.yml")
            self.assertEqual(jobs[f"{component}_test"]["uses"], "./.github/workflows/test-components.yml")
            self.assertEqual(jobs[f"{component}_release"]["uses"], "./.github/workflows/release-components.yml")
            command = "\n".join(step.get("run", "") for step in gate["steps"])
            self.assertIn('"${BUILD_RESULT}" == success', command)
            self.assertIn('"${TEST_RESULT}" == success', command)
            self.assertIn('"${RELEASE_RESULT}" == success', command)
            self.assertIn('"${ALREADY_CURRENT}" == true', command)
            self.assertIn('"${EVENT_NAME}" == pull_request', command)

        for previous, following in (
            ("zookeeper", "hadoop"),
            ("hadoop", "tez"),
            ("tez", "hive"),
            ("hive", "spark"),
            ("spark", "hbase"),
        ):
            condition = jobs[f"{following}_repo_check"]["if"]
            self.assertIn(f"needs.{previous}_gate.outputs.continue_chain", condition)

        config = subprocess.run(
            ["ruby", "-ryaml", "-rjson", "-e", 'puts JSON.generate(YAML.load_file(ARGV.fetch(0)))', str(COMPONENTS)],
            text=True,
            capture_output=True,
            check=True,
        ).stdout
        versions = json.loads(config)["components"]
        self.assertEqual(
            set(versions["zookeeper"]["runtime_packages"]),
            {"zookeeper", "zookeeper-native", "zookeeper-rest", "zookeeper-server"},
        )
        self.assertEqual(
            set(versions["hadoop"]["runtime_packages"]),
            {
                "hadoop", "hadoop-client", "hadoop-conf-pseudo", "hadoop-hdfs",
                "hadoop-hdfs-datanode", "hadoop-hdfs-dfsrouter", "hadoop-hdfs-fuse",
                "hadoop-hdfs-journalnode", "hadoop-hdfs-namenode",
                "hadoop-hdfs-secondarynamenode", "hadoop-hdfs-zkfc", "hadoop-httpfs",
                "hadoop-kms", "hadoop-libhdfs", "hadoop-libhdfspp", "hadoop-mapreduce",
                "hadoop-mapreduce-historyserver", "hadoop-yarn", "hadoop-yarn-nodemanager",
                "hadoop-yarn-proxyserver", "hadoop-yarn-resourcemanager", "hadoop-yarn-router",
                "hadoop-yarn-timelineserver",
            },
        )
        for component in ("zookeeper", "hadoop", "tez", "hive", "spark", "hbase"):
            self.assertEqual(jobs[f"{component}_build"]["with"]["version"], versions[component]["version"])

        build_script = (ROOT / "scripts/ci/build-bigtop-component.sh").read_text()
        test_script = (ROOT / "scripts/ci/test-bigtop-component.sh").read_text()
        for component in ("hadoop", "zookeeper"):
            self.assertIn(f"{component}-rpm-openeuler-container.sh", build_script)
            self.assertIn(f"{component}-rpm-openeuler-container.sh", test_script)
        workflow_text = COMPONENT_WORKFLOW.read_text()
        for component in ("zookeeper", "hadoop"):
            self.assertIn(f"          - {component}\n", workflow_text)

    def test_fast_path_contract_runs_in_ci_pr(self) -> None:
        workflow = subprocess.run(
            [
                "ruby",
                "-ryaml",
                "-e",
                'workflow = YAML.load_file(ARGV.fetch(0)); jobs = workflow.fetch("jobs"); steps = jobs.fetch("shell").fetch("steps"); puts steps.map { |step| step["run"] }.compact.join("\\n")',
                str(ROOT / ".github/workflows/ci-pr.yml"),
            ],
            text=True,
            capture_output=True,
            check=True,
        ).stdout
        self.assertIn("test-component-repo-fast-path.py", workflow)

    def test_stage_gate_success_and_failure_paths(self) -> None:
        jobs = self.workflow_jobs()
        cases = [
            ("success", "true", "skipped", "skipped", "skipped", "push", "false", 0, "continue_chain=true"),
            ("success", "true", "skipped", "skipped", "skipped", "pull_request", "false", 0, "continue_chain=true"),
            ("success", "true", "failure", "skipped", "skipped", "push", "false", 1, ""),
            ("success", "false", "success", "success", "success", "push", "false", 0, "continue_chain=true"),
            ("success", "false", "success", "success", "skipped", "pull_request", "false", 0, "continue_chain=true"),
            ("success", "false", "failure", "skipped", "skipped", "push", "false", 1, ""),
            ("success", "false", "success", "failure", "skipped", "pull_request", "false", 1, ""),
            ("success", "false", "skipped", "skipped", "skipped", "pull_request", "true", 0, "continue_chain=false"),
        ]
        for component in ("zookeeper", "hadoop", "tez", "hive", "spark", "hbase"):
            gate = jobs[f"{component}_gate"]
            step = gate["steps"][0]
            command = step["run"]
            for check, current, build, test, release, event, is_fork, status, output in cases:
                with self.subTest(component=component, build=build, test=test, release=release, event=event):
                    with tempfile.TemporaryDirectory() as directory:
                        output_file = Path(directory) / "github-output"
                        env = {
                            **os.environ,
                            "GITHUB_OUTPUT": str(output_file),
                            "CHECK_RESULT": check,
                            "ALREADY_CURRENT": current,
                            "BUILD_RESULT": build,
                            "TEST_RESULT": test,
                            "RELEASE_RESULT": release,
                            "EVENT_NAME": event,
                            "IS_FORK_PR": is_fork,
                        }
                        result = subprocess.run(
                            ["bash", "-e", "-c", command],
                            cwd=ROOT,
                            env=env,
                            text=True,
                            capture_output=True,
                            check=False,
                        )
                        self.assertEqual(result.returncode, status, result.stderr + result.stdout)
                        actual_output = output_file.read_text() if output_file.exists() else ""
                        if component == "hbase" and output == "continue_chain=false":
                            output = ""
                        if output:
                            self.assertIn(output, actual_output)
                        else:
                            self.assertNotIn("continue_chain=true", actual_output)

    def test_release_replaces_stale_existing_repo_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tested = root / "tested"
            test_evidence = root / "test-evidence"
            repo = root / "repo"
            target = repo / "repo/openeuler-22.03-lts-sp4/bigtop-3.6/tez/0.10.5"
            tested_rpms = tested / "rpms"
            (tested / "evidence").mkdir(parents=True)
            tested_rpms.mkdir(parents=True)
            test_evidence.mkdir()
            target.mkdir(parents=True)
            release_rpm = "tez-0.10.5-2.noarch.rpm"
            rpm_path = tested_rpms / release_rpm
            rpm_path.write_bytes(b"fresh tested RPM")
            rpm_hash = hashlib.sha256(rpm_path.read_bytes()).hexdigest()
            (tested / "evidence/SHA256SUMS").write_text(f"{rpm_hash}  rpms/{release_rpm}\n")
            (test_evidence / "evidence.md").write_text(
                "status: PASS\ncomponent: tez\nversion: 0.10.5\n"
            )
            (target / "manifest.yaml").write_text(
                "component: tez\nversion: 0.10.5\ntest_status: PASS\n"
            )
            (target / "tez-0.10.5-1.noarch.rpm").write_text("stale LFS pointer")
            (root / "bin").mkdir()
            createrepo = root / "bin/createrepo_c"
            createrepo.write_text(
                "#!/usr/bin/env bash\n"
                'target="${@: -1}"\n'
                'mkdir -p "${target}/repodata"\n'
                "printf '%s\\n' '<repomd/>' > \"${target}/repodata/repomd.xml\"\n"
            )
            createrepo.chmod(0o755)
            result = subprocess.run(
                ["bash", str(STAGER)],
                env={
                    **os.environ,
                    "PATH": f"{root / 'bin'}:{os.environ['PATH']}",
                    "COMPONENT": COMPONENT,
                    "VERSION": VERSION,
                    "TEST_RUN_ID": "123456",
                    "SOURCE_SHA": "a" * 40,
                    "REPO_CHECKOUT": str(repo),
                    "TESTED_RPMS_DIR": str(tested),
                    "TEST_EVIDENCE_DIR": str(test_evidence),
                },
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            self.assertFalse((target / "tez-0.10.5-1.noarch.rpm").exists())
            self.assertTrue((target / release_rpm).exists())
            self.assertIn(rpm_hash, (target / "SHA256SUMS").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)

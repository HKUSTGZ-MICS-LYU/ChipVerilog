#!/usr/bin/env python3
"""Compatibility entry point for the artifact-evaluation metric script."""

from pathlib import Path
import runpy


runpy.run_path(
    str(Path(__file__).resolve().parent / "artifact_evaluation" / "reproduce_metrics.py"),
    run_name="__main__",
)

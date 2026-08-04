#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIEWS = ROOT / "macos/TokenBarMac/Sources/TokenBarMac/TokenBarViews.swift"
TESTS = ROOT / "macos/TokenBarMac/Tests/TokenBarMacTests/TokenBarOnboardingTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    views = VIEWS.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for marker in [
        "TokenBarOnboardingView",
        "OnboardingAssemblyRail",
        "FIRST-RUN PATH",
        "Account",
        "Evidence",
        "Analyze",
        "MCQ",
        "Budget Brief",
        "Enter App",
        "sound + haptics off",
        "Nothing is uploaded. Account connection happens later",
        "asks three quick questions",
        "finish()",
    ]:
        require(marker in views, f"native onboarding missing marker: {marker}")

    require("phase = .questions" in views, "onboarding does not move to questions after analysis")
    require("phase = .reveal" in views, "onboarding does not reveal after MCQ answers")
    require("UserDefaults.standard.set(false, forKey: \"tokenbar.sound.enabled\")" in views, "sound should be disabled on first run")
    require("UserDefaults.standard.set(false, forKey: \"tokenbar.haptics.enabled\")" in views, "haptics should be disabled on first run")
    require("UserDefaults.standard.set(false, forKey: \"tokenbar.cinematicSound.enabled\")" in views, "cinematic sound should be disabled on first run")

    require("onboardingQuestionsComeFromTheAnalyzedProfile" in tests, "onboarding question test missing")
    require("onboardingQuestionsAvoidProviderTokenEntryCopy" in tests, "onboarding token-entry guard test missing")

    stale = [
        "Enter token",
        "Paste token",
        "API key",
        "Connect first. Analyze later.",
    ]
    for marker in stale:
        require(marker not in views, f"native onboarding contains stale copy: {marker}")

    print("native_onboarding_contract: PASS")


if __name__ == "__main__":
    main()

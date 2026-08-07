# Controlled App Store Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing `main` release lane sign reliably in GitHub Actions while defaulting every App Store run to upload-only control.

**Architecture:** Keep the existing Fastlane release lane and signing repository. Initialize Fastlane's CI keychain immediately before `match`, and make review submission opt-in so build upload, App Review submission, and manual public release remain separate gates.

**Tech Stack:** Ruby, Fastlane, match, GitHub Actions

## Global Constraints

- Reuse App Store Connect app `6771073144` and bundle identifier `Dan.Visual-Timer`.
- Do not create a replacement app record or bundle identifier.
- Do not change app code, pricing, IAP strategy, availability, or ownership in this repository hotfix.
- App Store upload must not submit for App Review unless explicitly opted in.
- Public release must remain manual.
- Run every Apple build or test through `/Users/dfakkeldy/.claude/bin/xcode-build-slot.sh -- <command>`.

---

### Task 1: Initialize Fastlane's CI signing keychain

**Files:**
- Create: `Scripts/release_automation/tests/fastfile_release_controls_test.rb`
- Modify: `fastlane/Fastfile:25-84`

**Interfaces:**
- Consumes: GitHub Actions `CI=true`, the existing `MATCH_PASSWORD`, and the existing match signing repository.
- Produces: `ci_environment? -> Boolean`; `sync_release_signing(api_key)` calls `setup_ci` before `match` only in CI.

- [x] **Step 1: Create the Fastfile behavior harness**

```ruby
require "minitest/autorun"

RELEASE_EVENTS = []
RELEASE_LANES = {}
RELEASE_UPLOADS = []

module SharedValues
  MATCH_PROVISIONING_PROFILE_MAPPING = :match_profile_mapping
end

Object.class_eval do
  private

  def default_platform(*)
  end

  def platform(*)
    yield
  end

  def desc(*)
  end

  def lane(name, &block)
    RELEASE_LANES[name] = block
  end

  def setup_ci
    RELEASE_EVENTS << :setup_ci
  end

  def match(**)
    RELEASE_EVENTS << :match
  end

  def lane_context
    { SharedValues::MATCH_PROVISIONING_PROFILE_MAPPING => {} }
  end
end

fastfile = File.expand_path("../../../fastlane/Fastfile", __dir__)
TOPLEVEL_BINDING.eval(File.read(fastfile), fastfile)

Object.class_eval do
  private

  def project_target_names
    []
  end

  def app_store_connect_key
    :api_key
  end

  def increment_release_build_number(*)
  end

  def build_release(*)
    "/tmp/TurnTimer.ipa"
  end

  def upload_to_app_store(**options)
    RELEASE_UPLOADS << options
  end
end

class FastfileReleaseControlsTest < Minitest::Test
  def setup
    RELEASE_EVENTS.clear
    RELEASE_UPLOADS.clear
    @original_ci = ENV["CI"]
    @original_submit = ENV["APP_STORE_SUBMIT_FOR_REVIEW"]
    @original_automatic = ENV["APP_STORE_AUTOMATIC_RELEASE"]
  end

  def teardown
    ENV["CI"] = @original_ci
    ENV["APP_STORE_SUBMIT_FOR_REVIEW"] = @original_submit
    ENV["APP_STORE_AUTOMATIC_RELEASE"] = @original_automatic
  end

  def test_ci_initializes_temporary_keychain_before_match
    ENV["CI"] = "true"

    sync_release_signing(:api_key)

    assert_equal [:setup_ci, :match], RELEASE_EVENTS
  end

  def test_app_store_upload_does_not_submit_or_release_by_default
    ENV.delete("CI")
    ENV.delete("APP_STORE_SUBMIT_FOR_REVIEW")
    ENV.delete("APP_STORE_AUTOMATIC_RELEASE")

    RELEASE_LANES.fetch(:app_store).call

    upload_options = RELEASE_UPLOADS.fetch(0)
    assert_equal false, upload_options.fetch(:submit_for_review)
    assert_equal false, upload_options.fetch(:automatic_release)
  end
end
```

The first test catches removal or misordering of CI keychain initialization. The second catches an unsafe fallback that submits or releases when control variables are absent.

- [x] **Step 2: Run the behavior tests and verify both fail for the expected reasons**

```bash
ruby Scripts/release_automation/tests/fastfile_release_controls_test.rb
```

Expected: two assertion failures: `[:match]` instead of `[:setup_ci, :match]`, and `true` instead of `false` for `submit_for_review`.

- [x] **Step 3: Add the minimal CI helper and keychain initialization**

```ruby
def ci_environment?
  ENV["CI"].to_s.casecmp("true").zero?
end

def sync_release_signing(api_key)
  refresh_profiles = boolean_env("MATCH_REFRESH_PROFILES", default: false)
  readonly = ci_environment? && !refresh_profiles
  targets = signing_targets

  setup_ci if ci_environment?
  # Existing match and signing mapping remain unchanged.
end
```

- [x] **Step 4: Re-run only the signing test**

```bash
ruby Scripts/release_automation/tests/fastfile_release_controls_test.rb --name test_ci_initializes_temporary_keychain_before_match
```

Expected: 1 run, 1 assertion, 0 failures.

### Task 2: Default App Store runs to upload-only

**Files:**
- Modify: `.github/workflows/ci.yml:34-54`
- Modify: `fastlane/Fastfile:141-159`

**Interfaces:**
- Consumes: optional `APP_STORE_SUBMIT_FOR_REVIEW` and `APP_STORE_AUTOMATIC_RELEASE` environment variables.
- Produces: the `app_store` lane uploads a binary but does not submit it or release it unless those controls are explicitly enabled.

- [x] **Step 1: Re-run the upload-control test and confirm it remains red**

```bash
ruby Scripts/release_automation/tests/fastfile_release_controls_test.rb --name test_app_store_upload_does_not_submit_or_release_by_default
```

Expected: one assertion failure: `true` instead of `false` for `submit_for_review`.

- [x] **Step 2: Make review submission opt-in**

```ruby
submit_for_review = boolean_env("APP_STORE_SUBMIT_FOR_REVIEW", default: false)
automatic_release = boolean_env("APP_STORE_AUTOMATIC_RELEASE", default: false)
```

- [x] **Step 3: Add the behavior test to the protected-branch CI gate**

```yaml
- name: Validate release controls
  run: ruby Scripts/release_automation/tests/fastfile_release_controls_test.rb
```

- [x] **Step 4: Re-run behavior tests and syntax checks**

```bash
ruby Scripts/release_automation/tests/fastfile_release_controls_test.rb
ruby -c fastlane/Fastfile
git diff --check
```

Expected: every command exits 0; syntax output is `Syntax OK`.

### Task 3: Keep Pro copy accurate for the `main` candidate

**Files:**
- Modify: `Visual Timer/ProPaywallView.swift:23`
- Modify: `Visual Timer/SettingsView.swift:87`

**Interfaces:**
- Consumes: the feature set actually present on `main`, which has no widget target.
- Produces: customer-visible Pro copy that promises only unlimited templates, full history/export, iCloud sync, and sharing.

- [x] **Step 1: Confirm the candidate has no widget target**

```bash
rg -n "TurnTimerWidgets|widget" "Visual Timer.xcodeproj/project.pbxproj" "Visual Timer"
```

Expected: no widget project target; only the two inaccurate customer-visible strings refer to widgets.

- [x] **Step 2: Remove the unsupported widget promise from both strings**

```swift
Label("iCloud sync and sharing", systemImage: Theme.Symbol.proFutureFeatures)
Text("Pro unlocks unlimited templates, full history export, iCloud template sync, and sharing.")
```

- [x] **Step 3: Verify the iOS and watch schemes without bypassing the build-slot policy**

```bash
/Users/dfakkeldy/.claude/bin/xcode-build-slot.sh -- xcodebuild test -project "Visual Timer.xcodeproj" -scheme "Visual Timer" -destination "platform=iOS Simulator,id=<discovered-udid>" -resultBundlePath "<timestamped-path>" CODE_SIGNING_ALLOWED=NO
/Users/dfakkeldy/.claude/bin/xcode-build-slot.sh -- xcodebuild build -project "Visual Timer.xcodeproj" -scheme "Visual Timer Watch Watch App" -destination "generic/platform=watchOS Simulator" CODE_SIGNING_ALLOWED=NO
```

Expected: both wrapper-controlled commands exit 0; the iOS result bundle reports no test failures.

The local wrapper correctly held at warning memory pressure, so no local Apple build was started. Equivalent fresh proof ran on the protected hosted macOS runner in GitHub Actions run `31175746906`: release-control test, iOS build-for-testing, watchOS build, and iOS unit tests all passed.

- [x] **Step 4: Commit the coherent release-control hotfix**

Dan then added commit `30b99e4` to keep internal nightly uploads out of external Beta App Review while preserving external distribution for the `weekly` lane.

```bash
git add .github/workflows/ci.yml Scripts/release_automation/tests/fastfile_release_controls_test.rb "Visual Timer/ProPaywallView.swift" "Visual Timer/SettingsView.swift" fastlane/Fastfile docs/superpowers/plans/2026-08-07-controlled-app-store-release.md
git commit -m "fix: make App Store release controlled"
```

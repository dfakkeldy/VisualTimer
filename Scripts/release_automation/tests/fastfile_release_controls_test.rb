require "minitest/autorun"

RELEASE_EVENTS = []
RELEASE_LANES = {}
RELEASE_UPLOADS = []
TESTFLIGHT_UPLOADS = []

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

  def upload_to_testflight(**options)
    TESTFLIGHT_UPLOADS << options
  end
end

class FastfileReleaseControlsTest < Minitest::Test
  def setup
    RELEASE_EVENTS.clear
    RELEASE_UPLOADS.clear
    TESTFLIGHT_UPLOADS.clear
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
    assert_equal false, upload_options.fetch(:run_precheck_before_submit)
  end

  def test_beta_channels_only_target_a_group_for_external_distribution
    RELEASE_LANES.fetch(:beta).call(channel: "nightly")
    RELEASE_LANES.fetch(:beta).call(channel: "weekly")

    nightly_options, weekly_options = TESTFLIGHT_UPLOADS
    assert_equal false, nightly_options.fetch(:distribute_external)
    refute nightly_options.key?(:groups)
    refute nightly_options.key?(:notify_external_testers)
    assert_equal true, weekly_options.fetch(:distribute_external)
    assert_equal ["weekly"], weekly_options.fetch(:groups)
    assert_equal true, weekly_options.fetch(:notify_external_testers)
  end
end

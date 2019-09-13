require 'fileutils'
require 'yaml'
require "#{Dir.pwd}/features/support/helpers/misc_helpers.rb"

# These files deal with options like some of the settings passed
# to the `run_test_suite` script, and "secrets" like credentials
# (passwords, SSH keys) to be used in tests.
CONFIG_DIR = "#{Dir.pwd}/features/config"
DEFAULTS_CONFIG_FILE = "#{CONFIG_DIR}/defaults.yml"
LOCAL_CONFIG_FILE = "#{CONFIG_DIR}/local.yml"
LOCAL_CONFIG_DIRS_FILES_GLOB = "#{CONFIG_DIR}/*.d/*.yml"

assert File.exists?(DEFAULTS_CONFIG_FILE)
$config = YAML.load(File.read(DEFAULTS_CONFIG_FILE))
config_files = Dir.glob(LOCAL_CONFIG_DIRS_FILES_GLOB).sort
config_files.insert(0, LOCAL_CONFIG_FILE) if File.exists?(LOCAL_CONFIG_FILE)
config_files.each do |config_file|
  yaml_struct = YAML.load(File.read(config_file)) || Hash.new
  if not(yaml_struct.instance_of?(Hash))
    raise "Local configuration file '#{config_file}' is malformed"
  end
  $config.merge!(yaml_struct)
end
# Options passed to the `run_test_suite` script will always take
# precedence. The way we import these keys is only safe for values
# with types boolean or string. If we need more, we'll have to invoke
# YAML's type autodetection on ENV some how.
$config.merge!(ENV)

# Export TMPDIR back to the environment for subprocesses that we start
# (e.g. guestfs). Note that this export will only make a difference if
# TMPDIR wasn't already set and --tmpdir wasn't passed, i.e. only when
# we use the default.
ENV['TMPDIR'] = $config['TMPDIR']

# Dynamic constants initialized through the environment or similar,
# e.g. options we do not want to be configurable through the YAML
# configuration files.
DEBUG_LOG_PSEUDO_FIFO = "#{$config["TMPDIR"]}/debug_log_pseudo_fifo"
DISPLAY = ENV['DISPLAY']
GIT_DIR = ENV['PWD']
KEEP_SNAPSHOTS = !ENV['KEEP_SNAPSHOTS'].nil?
LIVE_USER = cmd_helper(". config/chroot_local-includes/etc/live/config.d/username.conf; echo ${LIVE_USERNAME}").chomp
TAILS_ISO = ENV['TAILS_ISO']
TAILS_IMG = TAILS_ISO.sub(/\.iso/, '.img')
OLD_TAILS_ISO = ENV['OLD_TAILS_ISO'] || TAILS_ISO
OLD_TAILS_IMG = OLD_TAILS_ISO.sub(/\.iso/, '.img')
TIME_AT_START = Time.now
loop do
  ARTIFACTS_DIR = $config['TMPDIR'] + "/run-" +
                  sanitize_filename(TIME_AT_START.to_s) + "-" +
                  [
                    "git",
                    sanitize_filename(describe_git_head,
                                      :replacement => '-'),
                    current_short_commit
                  ].reject(&:empty?).join("_") + "-" +
                  random_alnum_string(6)
  if not(File.exist?(ARTIFACTS_DIR))
    FileUtils.mkdir_p(ARTIFACTS_DIR)
    break
  end
end
SIKULI_CANDIDATES_DIR = "#{ARTIFACTS_DIR}/sikuli_candidates"
SIKULI_IMAGE_PATH = "#{Dir.pwd}/features/images/"
SIKULI_MIN_SIMILARITY = 0.9

# Constants that are statically initialized.
CONFIGURED_KEYSERVER_HOSTNAME = 'jirk5u4osbsr34t5.onion'
LIBVIRT_DOMAIN_NAME = "TailsToaster"
LIBVIRT_DOMAIN_UUID = "203552d5-819c-41f3-800e-2c8ef2545404"
LIBVIRT_NETWORK_NAME = "TailsToasterNet"
LIBVIRT_NETWORK_UUID = "f2305af3-2a64-4f16-afe6-b9dbf02a597e"
MISC_FILES_DIR = "#{Dir.pwd}/features/misc_files"
SERVICES_EXPECTED_ON_ALL_IFACES =
  [
   ["cupsd",    "*", "631"],
   ["dhclient", "0.0.0.0", "68"]
  ]
# OpenDNS
SOME_DNS_SERVER = "208.67.222.222"
VM_XML_PATH = "#{Dir.pwd}/features/domains"

TAILS_SIGNING_KEY = cmd_helper(". #{Dir.pwd}/config/amnesia; echo ${AMNESIA_DEV_KEYID}").tr(' ', '').chomp
TAILS_DEBIAN_REPO_KEY = "221F9A3C6FA3E09E182E060BC7988EA7A358D82E"
WEBM_VIDEO_URL = 'https://tails.boum.org/lib/test_suite/test.webm'

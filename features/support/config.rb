require 'fileutils'
require 'yaml'
require "#{Dir.pwd}/features/support/helpers/misc_helpers.rb"

# These two files deal with options like some of the settings passed
# to the `run_test_suite` script, and "secrets" like credentials
# (passwords, SSH keys) to be used in tests.
DEFAULTS_CONFIG_FILE = "#{Dir.pwd}/features/config/defaults.yml"
LOCAL_CONFIG_FILE = "#{Dir.pwd}/features/config/local.yml"

assert File.exists?(DEFAULTS_CONFIG_FILE)
$config = YAML.load(File.read(DEFAULTS_CONFIG_FILE))
if File.exists?(LOCAL_CONFIG_FILE)
  $config.merge!(YAML.load(File.read(LOCAL_CONFIG_FILE)))
end
# Options passed to the `run_test_suite` script will always take
# precedence.
$config.merge!(ENV)

# Dynamic
TAILS_ISO = ENV['ISO'] || raise "No ISO set with --iso"
OLD_TAILS_ISO = ENV['OLD_ISO'] || raise "No old ISO set with --old-iso"
VM_XML_PATH = "#{Dir.pwd}/features/domains"
MISC_FILES_DIR = "#{Dir.pwd}/features/misc_files"
KEEP_SNAPSHOTS = !ENV['KEEP_SNAPSHOTS'].nil?
DISPLAY = ENV['DISPLAY']
TIME_AT_START = Time.now
LIVE_USER = cmd_helper(". config/chroot_local-includes/etc/live/config.d/username.conf; echo ${LIVE_USERNAME}").chomp
GIT_DIR = ENV['PWD']

# Static
$configured_keyserver_hostname = 'hkps.pool.sks-keyservers.net'
$services_expected_on_all_ifaces =
  [
   ["cupsd",    "0.0.0.0", "631"],
   ["dhclient", "0.0.0.0", "*"]
  ]
$tor_authorities =
  # List grabbed from Tor's sources, src/or/config.c:~750.
  [
   "128.31.0.39", "86.59.21.38", "194.109.206.212",
   "82.94.251.203", "76.73.17.194", "212.112.245.170",
   "193.23.244.244", "208.83.223.34", "171.25.193.9",
   "154.35.32.5"
  ]
# OpenDNS
$some_dns_server = "208.67.222.222"

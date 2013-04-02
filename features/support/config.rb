$configured_keyserver_hostname = 'hkps.pool.sks-keyservers.net'
$services_expected_on_all_ifaces =
  [
   ["cupsd",    "0.0.0.0", "631"],
   ["dhclient", "0.0.0.0", "68"]
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

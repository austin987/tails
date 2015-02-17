require 'fileutils'
require "#{Dir.pwd}/features/support/helpers/misc_helpers.rb"

# Dynamic
$tails_iso = ENV['ISO'] || get_newest_iso
$old_tails_iso = ENV['OLD_ISO'] || get_oldest_iso
$tmp_dir = ENV['TEMP_DIR'] || "/tmp/TailsToaster"
$vm_xml_path = ENV['VM_XML_PATH'] || "#{Dir.pwd}/features/domains"
$misc_files_dir = "#{Dir.pwd}/features/misc_files"
$keep_snapshots = !ENV['KEEP_SNAPSHOTS'].nil?
$x_display = ENV['DISPLAY']
$debug = !ENV['DEBUG'].nil?
$pause_on_fail = !ENV['PAUSE_ON_FAIL'].nil?
$time_at_start = Time.now
$live_user = cmd_helper(". config/chroot_local-includes/etc/live/config.d/username.conf; echo ${LIVE_USERNAME}").chomp
$sikuli_retry_findfailed = !ENV['SIKULI_RETRY_FINDFAILED'].nil?
$git_dir = ENV['PWD']

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

$tails_test_secret_ssh_key = <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAvMUNgUUM/kyuo26m+Xw7igG6zgGFMFbS3u8m5StGsJOn7zLi
J8P5Mml/R+4tdOS6owVU4RaZTPsNZZK/ClYmOPhmNvJ04pVChk2DZ8AARg/TANj3
qjKs3D+MeKbk1bt6EsA55kgGsTUky5Ti8cc2Wna25jqjagIiyM822PGG9mmI6/zL
YR6QLUizNaciXrRM3Q4R4sQkEreVlHeonPEiGUs9zx0swCpLtPM5UIYte1PVHgkw
ePsU6vM8UqVTK/VwtLLgLanXnsMFuzq7DTAXPq49+XSFNq4JlxbEF6+PQXZvYZ5N
eW00Gq7NSpPP8uoHr6f1J+mMxxnM85jzYtRx+QIDAQABAoIBAA8Bs1MlhCTrP67q
awfGYo1UGd+qq0XugREL/hGV4SbEdkNDzkrO/46MaHv1aVOzo0q2b8r9Gu7NvoDm
q51Mv/kjdizEFZq1tvYqT1n+H4dyVpnopbe4E5nmy2oECokbQFchRPkTnMSVrvko
OupxpdaHPX8MBlW1GcLRBlE00j/gfK1SXX5rcxkF5EHVND1b6iHddTPearDbU8yr
wga1XO6WeohAYzqmGtMD0zk6lOk0LmnTNG6WvHiFTAc/0yTiKub6rNOIEMS/82+V
l437H0hKcIN/7/mf6FpqRNPJTuhOVFf+L4G/ZQ8zHoMGVIbhuTiIPqZ/KMu3NaUF
R634jckCgYEA+jJ31hom/d65LfxWPkmiSkNTEOTfjbfcgpfc7sS3enPsYnfnmn5L
O3JJzAKShSVP8NVuPN5Mg5FGp9QLKrN3kV6QWQ3EnqeW748DXMU6zKGJQ5wo7ZVm
w2DhJ/3PAuBTL/5X4mjPQL+dr86Aq2JBDC7LHJs40I8O7UbhnsdMxKcCgYEAwSXc
3znAkAX8o2g37RiAl36HdONgxr2eaGK7OExp03pbKmoISw6bFbVpicBy6eTytn0A
2PuFcBKJRfKrViHyiE8UfAJ31JbUaxpg4bFF6UEszN4CmgKS8fnwEe1aX0qSjvkE
NQSuhN5AfykXY/1WVIaWuC500uB7Ow6M16RDyF8CgYEAqFTeNYlg5Hs+Acd9SukF
rItBTuN92P5z+NUtyuNFQrjNuK5Nf68q9LL/Hag5ZiVldHZUddVmizpp3C6Y2MDo
WEDUQ2Y0/D1rGoAQ1hDIb7bbAEcHblmPSzJaKirkZV4B+g9Yl7bGghypfggkn6o6
c3TkKLnybrdhZpjC4a3bY48CgYBnWRYdD27c4Ycz/GDoaZLs/NQIFF5FGVL4cdPR
pPl/IdpEEKZNWwxaik5lWedjBZFlWe+pKrRUqmZvWhCZruJyUzYXwM5Tnz0b7epm
+Q76Z1hMaoKj27q65UyymvkfQey3ucCpic7D45RJNjiA1R5rbfSZqqnx6BGoIPn1
rLxkKwKBgDXiWeUKJCydj0NfHryGBkQvaDahDE3Yigcma63b8vMZPBrJSC4SGAHJ
NWema+bArbaF0rKVJpwvpkZWGcr6qRn94Ts0kJAzR+VIVTOjB9sVwdxjadwWHRs5
kKnpY0tnSF7hyVRwN7GOsNDJEaFjCW7k4+55D2ZNBy2iN3beW8CZ
-----END RSA PRIVATE KEY-----
EOF

$tails_test_public_ssh_key = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8xQ2BRQz+TK6jbqb5fDuKAbrOAYUwVtLe7yblK0awk6fvMuInw/kyaX9H7i105LqjBVThFplM+w1lkr8KViY4+GY28nTilUKGTYNnwABGD9MA2PeqMqzcP4x4puTVu3oSwDnmSAaxNSTLlOLxxzZadrbmOqNqAiLIzzbY8Yb2aYjr/MthHpAtSLM1pyJetEzdDhHixCQSt5WUd6ic8SIZSz3PHSzAKku08zlQhi17U9UeCTB4+xTq8zxSpVMr9XC0suAtqdeewwW7OrsNMBc+rj35dIU2rgmXFsQXr49Bdm9hnk15bTQars1Kk8/y6gevp/Un6YzHGczzmPNi1HH5 amnesia@amnesia'

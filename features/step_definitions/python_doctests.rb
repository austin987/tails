Then /^the Python doctests for the (.*) script pass$/ do |script|
  cmd_helper(['./config/chroot_local-includes/' + script, 'doctest'])
end

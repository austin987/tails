When /^I query the whois directory service for "([^"]+)"$/ do |domain|
  next if @skip_steps_while_restoring_background
  tries = 0
  until tries == $config["MAX_NEW_TOR_CIRCUIT_RETRIES"] do
    begin
      @vm_execute_res = @vm.execute_successfully("whois '#{domain}'", LIVE_USER)
      assert(@vm_execute_res.stdout.downcase[domain])
      break
    rescue ExecutionFailedInVM, Test::Unit::AssertionFailedError
      tries += 1
      STDERR.puts "Forcing new Tor circuit... (attempt ##{tries})" if $config["DEBUG"]
      step 'I force Tor to use a new circuit'
    end
  end
  assert(tries <= $config["MAX_NEW_TOR_CIRCUIT_RETRIES"],
         "Looking up whois info for #{domain} did not succeed after retrying #{tries} times.\n" +
         "The whois standard output does not contain #{domain}:\n" +
         "#{@vm_execute_res.stdout}\n" + "#{@vm_execute_res.stderr}")
end

When /^I wget "([^"]+)" to stdout(?:| with the '([^']+)' options)$/ do |url, options|
  next if @skip_steps_while_restoring_background
  arguments = "-O - '#{url}'"
  arguments = "#{options} #{arguments}" if options
  @vm_execute_res = @vm.execute(
    "wget #{arguments}",
    LIVE_USER)
end

Then /^the (wget|whois) command is successful$/ do |command|
  next if @skip_steps_while_restoring_background
  assert(
    @vm_execute_res.success?,
    "#{command} failed:\n" +
    "#{@vm_execute_res.stdout}\n" +
    "#{@vm_execute_res.stderr}"
  )
end

Then /^the (wget|whois) standard output contains "([^"]+)"$/ do |command, text|
  next if @skip_steps_while_restoring_background
  assert(
    @vm_execute_res.stdout[text],
    "The #{command} standard output does not contain #{text}:\n" +
    "#{@vm_execute_res.stdout}\n" +
    "#{@vm_execute_res.stderr}"
  )
end

class WhoisLookupFailure < StandardError
end

When /^I successfully query the whois directory service for "([^"]+)"$/ do |domain|
  next if @skip_steps_while_restoring_background
  @new_circuit_tries = 0
  until @new_circuit_tries == $config["MAX_NEW_TOR_CIRCUIT_RETRIES"] do
    begin
      @vm_execute_res = @vm.execute("whois '#{domain}'", LIVE_USER)
      assert(!@vm_execute_res.stdout['LIMIT EXCEEDED'])
      raise WhoisLookupFailure unless @vm_execute_res.success?
      break
    rescue Test::Unit::AssertionFailedError
      force_new_tor_circuit
    rescue WhoisLookupFailure => e
      if @vm_execute_res.stderr['Timeout'] || @vm_execute_res.stderr['Unable to resolve']
        force_new_tor_circuit
      else
        raise e
      end
    end
  end
  assert(@new_circuit_tries < $config["MAX_NEW_TOR_CIRCUIT_RETRIES"],
         "Looking up whois info for #{domain} did not succeed after retrying #{@new_circuit_tries} times.\n" +
         "The output of the last command contains:\n" +
         "#{@vm_execute_res.stdout}\n" + "#{@vm_execute_res.stderr}")
end

When /^I successfully wget "([^"]+)" to stdout(?:| with the '([^']+)' options)$/ do |url, options|
  next if @skip_steps_while_restoring_background
  arguments = "-O - '#{url}'"
  arguments = "#{options} #{arguments}" if options
  @vm_execute_res = @vm.execute_successfully("wget #{arguments}", LIVE_USER)
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

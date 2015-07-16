class WhoisLookupFailure < StandardError
end

class WgetFailure < StandardError
end

When /^I query the whois directory service for "([^"]+)"$/ do |domain|
  next if @skip_steps_while_restoring_background
  @new_circuit_tries = 0
  until @new_circuit_tries == $config["MAX_NEW_TOR_CIRCUIT_RETRIES"] do
    begin
      @vm_execute_res = @vm.execute("whois '#{domain}'", LIVE_USER)
      if !@vm_execute_res.success? || @vm_execute_res.stdout['LIMIT EXCEEDED']
        raise WhoisLookupFailure
      end
      break
    rescue WhoisLookupFailure
      if @vm_execute_res.stderr['Timeout'] || \
         @vm_execute_res.stderr['Unable to resolve'] || \
         @vm_execute_res.stdout['LIMIT EXCEEDED']
        force_new_tor_circuit
      end
    end
  end
  assert(@new_circuit_tries < $config["MAX_NEW_TOR_CIRCUIT_RETRIES"],
         "Looking up whois info for #{domain} did not succeed after retrying #{@new_circuit_tries} times.\n" +
         "The output of the last command contains:\n" +
         "#{@vm_execute_res.stdout}\n" + "#{@vm_execute_res.stderr}")
end

When /^I wget "([^"]+)" to stdout(?:| with the '([^']+)' options)$/ do |url, options|
  next if @skip_steps_while_restoring_background
  arguments = "-O - '#{url}'"
  arguments = "#{options} #{arguments}" if options

  @new_circuit_tries = 0
  until @new_circuit_tries == $config["MAX_NEW_TOR_CIRCUIT_RETRIES"] do
    begin
      @vm_execute_res = @vm.execute("wget #{arguments}", LIVE_USER)
      raise WgetFailure unless @vm_execute_res.success?
      break
    rescue WgetFailure
      if @vm_execute_res.stderr['Timeout'] || @vm_execute_res.stderr['Unable to resolve']
        force_new_tor_circuit
      end
    end
  end
  assert(@new_circuit_tries < $config["MAX_NEW_TOR_CIRCUIT_RETRIES"],
         "Fetching from #{url} with options #{options} did not succeed after retrying #{@new_circuit_tries} times.\n" +
         "The output contains:\n" +
         "#{@vm_execute_res.stdout}\n" +
         "#{@vm_execute_res.stderr}")
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

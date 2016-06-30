When /^I query the whois directory service for "([^"]+)"$/ do |domain|
  retry_tor do
    @vm_execute_res = $vm.execute("whois '#{domain}'", :user => LIVE_USER)
    if @vm_execute_res.failure? || @vm_execute_res.stdout['LIMIT EXCEEDED']
      raise "Looking up whois info for #{domain} failed with:\n" +
            "#{@vm_execute_res.stdout}\n" +
            "#{@vm_execute_res.stderr}"
    end
  end
end

When /^I wget "([^"]+)" to stdout(?:| with the '([^']+)' options)$/ do |url, options|
  arguments = "-O - '#{url}'"
  arguments = "#{options} #{arguments}" if options
  retry_tor do
    @vm_execute_res = $vm.execute("wget #{arguments}", :user => LIVE_USER)
    if @vm_execute_res.failure?
      raise "wget:ing #{url} with options #{options} failed with:\n" +
            "#{@vm_execute_res.stdout}\n" +
            "#{@vm_execute_res.stderr}"
    end
  end
end

Then /^the (wget|whois) command is successful$/ do |command|
  assert(
    @vm_execute_res.success?,
    "#{command} failed:\n" +
    "#{@vm_execute_res.stdout}\n" +
    "#{@vm_execute_res.stderr}"
  )
end

Then /^the (wget|whois) standard output contains "([^"]+)"$/ do |command, text|
  assert(
    @vm_execute_res.stdout[text],
    "The #{command} standard output does not contain #{text}:\n" +
    "#{@vm_execute_res.stdout}\n" +
    "#{@vm_execute_res.stderr}"
  )
end

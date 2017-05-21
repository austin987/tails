require 'resolv'

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

When /^I wget "([^"]+)" to stdout(?:| with the '([^']+)' options)$/ do |target, options|
  retry_tor do
    if target == "some Tails mirror"
      host = 'dl.amnesia.boum.org'
      address = Resolv.new.getaddresses(host).sample
      puts "Resolved #{host} to #{address}"
      url = "http://#{address}/tails/stable/"
    else
      url = target
    end
    arguments = "-O - '#{url}'"
    arguments = "#{options} #{arguments}" if options
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

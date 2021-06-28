require 'resolv'

When /^I wget "([^"]+)" to stdout(?:| with the '([^']+)' options)$/ do |target, options|
  retry_tor do
    if target == 'some Tails mirror'
      host = 'dl.amnesia.boum.org'
      address = Resolv.new.getaddresses(host).sample
      puts "Resolved #{host} to #{address}"
      url = "http://#{address}/tails/stable/"
    else
      url = target
    end
    arguments = "-O - '#{url}'"
    arguments = "#{options} #{arguments}" if options
    @vm_execute_res = $vm.execute("wget #{arguments}", user: LIVE_USER)
    if @vm_execute_res.failure?
      raise "wget:ing #{url} with options #{options} failed with:\n" \
            "#{@vm_execute_res.stdout}\n" +
            @vm_execute_res.stderr.to_s
    end
  end
end

Then /^the wget command is successful$/ do
  assert(
    @vm_execute_res.success?,
    "wget failed:\n" \
    "#{@vm_execute_res.stdout}\n" +
    @vm_execute_res.stderr.to_s
  )
end

Then /^the wget standard output contains "([^"]+)"$/ do |text|
  assert(
    @vm_execute_res.stdout[text],
    "The wget standard output does not contain #{text}:\n" \
    "#{@vm_execute_res.stdout}\n" +
    @vm_execute_res.stderr.to_s
  )
end

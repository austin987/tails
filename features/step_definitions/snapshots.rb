def reach_checkpoint(checkpoint_name)
  checkpoint_descs = {
    'no-network' => {
      :description => "Tails has booted from DVD, stopped at Tails Greeter's login screen",
      :restore_checkpoint => nil,
      :steps => [
        'I start Tails from DVD with network unplugged',
      ],
    },
    
    'no-network-logged-in' => {
      :description => "Tails has booted from DVD without network and logged in",
      :restore_checkpoint => "no-network",
      :steps => [
        'I log in to a new session',
        'Tails seems to have booted normally',
      ],
    },
    
    'with-network-logged-in' => {
      :description => "Tails has booted from DVD with network and logged in",
      :restore_checkpoint => "no-network",
      :steps => [
        'the network is plugged',
        'I log in to a new session',
        'Tails seems to have booted normally',
        'Tor is ready',
        'all notifications have disappeared',
        'available upgrades have been checked',
      ],
    },
    
    'usb-install' => {
      :description => "Tails has booted from a USB drive without a persistent partition, stopped at Tails Greeter's login screen" ,
      :restore_checkpoint => 'no-network-logged-in',
      :steps => [
        'I create a 4 GiB disk named "current"',
        'I plug USB drive "current"',
        'I "Clone & Install" Tails to USB drive "current"',
        'the running Tails is installed on USB drive "current"',
        'there is no persistence partition on USB drive "current"',
        'I shutdown Tails and wait for the computer to power off',
        'I start Tails from USB drive "current" with network unplugged',
        'the boot device has safe access rights',
        'Tails is running from USB drive "current"',
        'there is no persistence partition on USB drive "current"',
      ],
    },
    
    'usb-install-with-persistence' => {
      :description => "Tails has booted from a USB drive with a persistent partition, stopped at Tails Greeter's login screen",
      :restore_checkpoint => 'usb-install',
      :steps => [
        'I log in to a new session',
        'Tails seems to have booted normally',
        'I create a persistent partition with password "asdf"',
        'a Tails persistence partition with password "asdf" exists on USB drive "current"',
        'I shutdown Tails and wait for the computer to power off',
        'I start Tails from USB drive "current" with network unplugged',
        'the boot device has safe access rights',
        'Tails is running from USB drive "current"',
      ],
    },
  }
  step "a computer"
  if VM.snapshot_exists?(checkpoint_name)
    $vm.restore_snapshot(checkpoint_name)
    post_snapshot_restore_hook
  else
    checkpoint_desc = checkpoint_descs[checkpoint_name]
    description = checkpoint_desc[:description]
    restore_checkpoint = checkpoint_desc[:restore_checkpoint]
    steps = checkpoint_desc[:steps]
    if restore_checkpoint
      if not(VM.snapshot_exists?(restore_checkpoint))
        reach_checkpoint(restore_checkpoint)
      end
      $vm.restore_snapshot(restore_checkpoint)
      post_snapshot_restore_hook
    end
    STDERR.puts " "*4 + "Creating checkpoint '#{checkpoint_name}': " +
                description
    if restore_checkpoint
      STDERR.puts " "*6 + "I reach the \"#{restore_checkpoint}\" checkpoint"
    end
    steps.each do |s|
      begin
        step(s)
      rescue Exception => e
        STDERR.puts " "*4 + "Step failed while creating checkpoint " +
                    "'#{checkpoint_name}': #{s}"
        raise e
      end
      STDERR.puts " "*6 + s
    end
    $vm.save_snapshot(checkpoint_name)
  end
end

When /^I reach the "(.*)" checkpoint$/ do |checkpoint_name|
  reach_checkpoint(checkpoint_name)
end

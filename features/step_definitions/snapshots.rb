def checkpoints
  {
    'tails-greeter' => {
      :description => "I have started Tails from DVD without network and stopped at Tails Greeter's login screen",
      :parent_checkpoint => nil,
      :steps => [
        'the network is unplugged',
        'I start the computer',
        'the computer boots Tails'
      ],
    },

    'no-network-logged-in' => {
      :description => "I have started Tails from DVD without network and logged in",
      :parent_checkpoint => "tails-greeter",
      :steps => [
        'I log in to a new session',
      ],
    },

    'with-network-logged-in' => {
      :description => "I have started Tails from DVD and logged in and the network is connected",
      :parent_checkpoint => "no-network-logged-in",
      :steps => [
        'the network is plugged',
        'Tor is ready',
        'all notifications have disappeared',
        'available upgrades have been checked',
      ],
    },

    'no-network-bridge-mode' => {
      :temporary => true,
      :description => "I have started Tails from DVD without network and logged in with bridge mode enabled",
      :parent_checkpoint => "tails-greeter",
      :steps => [
        'I enable the specific Tor configuration option',
        'I log in to a new session',
        'all notifications have disappeared',
      ],
    },

    'no-network-logged-in-sudo-passwd' => {
      :temporary => true,
      :description => "I have started Tails from DVD without network and logged in with an administration password",
      :parent_checkpoint => "tails-greeter",
      :steps => [
        'I set an administration password',
        'I log in to a new session',
      ],
    },

    'with-network-logged-in-sudo-passwd' => {
      :temporary => true,
      :description => "I have started Tails from DVD and logged in with an administration password and the network is connected",
      :parent_checkpoint => "no-network-logged-in-sudo-passwd",
      :steps => [
        'the network is plugged',
        'Tor is ready',
        'all notifications have disappeared',
        'available upgrades have been checked',
      ],
    },

    'usb-install-tails-greeter' => {
      :description => "I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen",
      :parent_checkpoint => 'no-network-logged-in',
      :steps => [
        'I create a 7200 MiB disk named "__internal"',
        'I plug USB drive "__internal"',
        'I install Tails to USB drive "__internal" by cloning',
        'the running Tails is installed on USB drive "__internal"',
        'there is no persistence partition on USB drive "__internal"',
        'I shutdown Tails and wait for the computer to power off',
        'I start Tails from USB drive "__internal" with network unplugged',
        'the boot device has safe access rights',
        'Tails is running from USB drive "__internal"',
        'there is no persistence partition on USB drive "__internal"',
        'process "udev-watchdog" is running',
        'udev-watchdog is monitoring the correct device',
      ],
    },

    'usb-install-logged-in' => {
      :description => "I have started Tails without network from a USB drive without a persistent partition and logged in",
      :parent_checkpoint => 'usb-install-tails-greeter',
      :steps => [
        'I log in to a new session',
      ],
    },

    'usb-install-with-persistence-tails-greeter' => {
      :description => "I have started Tails without network from a USB drive with a persistent partition and stopped at Tails Greeter's login screen",
      :parent_checkpoint => 'usb-install-logged-in',
      :steps => [
        'I create a persistent partition',
        'a Tails persistence partition exists on USB drive "__internal"',
        'I shutdown Tails and wait for the computer to power off',
        'I start Tails from USB drive "__internal" with network unplugged',
        'the boot device has safe access rights',
        'Tails is running from USB drive "__internal"',
        'process "udev-watchdog" is running',
        'udev-watchdog is monitoring the correct device',
      ],
    },

    'usb-install-with-persistence-logged-in' => {
      :description => "I have started Tails without network from a USB drive with a persistent partition enabled and logged in",
      :parent_checkpoint => 'usb-install-with-persistence-tails-greeter',
      :steps => [
        'I enable persistence',
        'I log in to a new session',
        'all persistence presets are enabled',
        'all persistent filesystems have safe access rights',
        'all persistence configuration files have safe access rights',
        'all persistent directories have safe access rights',
      ],
    },

    'usb-install-with-persistence-logged-in-with-administration-password' => {
      :description => "I have started Tails without network from a USB drive with a persistent partition enabled and logged in with an administration password",
      :parent_checkpoint => 'usb-install-with-persistence-tails-greeter',
      :steps => [
        'I enable persistence',
        'I set an administration password',
        'I log in to a new session',
        'all persistence presets are enabled',
        'all persistent filesystems have safe access rights',
        'all persistence configuration files have safe access rights',
        'all persistent directories have safe access rights',
      ],
    },
  }
end

def reach_checkpoint(name)
  scenario_indent = " "*4
  step_indent = " "*6

  step "a computer"
  if VM.snapshot_exists?(name)
    $vm.restore_snapshot(name)
    post_snapshot_restore_hook
  else
    checkpoint = checkpoints[name]
    checkpoint_description = checkpoint[:description]
    parent_checkpoint = checkpoint[:parent_checkpoint]
    steps = checkpoint[:steps]
    if parent_checkpoint
      if VM.snapshot_exists?(parent_checkpoint)
        $vm.restore_snapshot(parent_checkpoint)
      else
        reach_checkpoint(parent_checkpoint)
      end
      post_snapshot_restore_hook
    end
    debug_log(scenario_indent + "Checkpoint: #{checkpoint_description}",
              color: :white, timestamp: false)
    step_action = "Given"
    if parent_checkpoint
      parent_description = checkpoints[parent_checkpoint][:description]
      debug_log(step_indent + "#{step_action} #{parent_description}",
                color: :green, timestamp: false)
      step_action = "And"
    end
    steps.each do |s|
      begin
        step(s)
      rescue Exception => e
        debug_log(scenario_indent +
                  "Step failed while creating checkpoint: #{s}",
                  color: :red, timestamp: false)
        raise e
      end
      debug_log(step_indent + "#{step_action} #{s}",
                color: :green, timestamp: false)
      step_action = "And"
    end
    $vm.save_snapshot(name)
  end
end

# For each checkpoint we generate a step to reach it.
checkpoints.each do |name, desc|
  step_regex = Regexp.new("^#{Regexp.escape(desc[:description])}$")
  Given step_regex do
    reach_checkpoint(name)
  end
end

def checkpoints
  {
    'tails-greeter' => {
      :description => "Tails has booted from DVD without network and stopped at Tails Greeter's login screen",
      :parent_checkpoint => nil,
      :steps => [
        'the network is unplugged',
        'I start the computer',
        'the computer boots Tails'
      ],
    },
    
    'no-network-logged-in' => {
      :description => "Tails has booted from DVD without network and logged in",
      :parent_checkpoint => "tails-greeter",
      :steps => [
        'I log in to a new session',
        'Tails Greeter has dealt with the sudo password',
        'the Tails desktop is ready',
      ],
    },
    
    'with-network-logged-in' => {
      :description => "Tails has booted from DVD and logged in and the network is connected",
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
      :description => "Tails has booted from DVD without network and logged in with bridge mode enabled",
      :parent_checkpoint => "tails-greeter",
      :steps => [
        'I enable more Tails Greeter options',
        'I enable the specific Tor configuration option',
        'I log in to a new session',
        'Tails Greeter has dealt with the sudo password',
        'the Tails desktop is ready',
        'all notifications have disappeared',
      ],
    },

    'no-network-windows-camouflage' => {
      :temporary => true,
      :description => "Tails has booted from DVD without network and logged in with windows camouflage enabled",
      :parent_checkpoint => "tails-greeter",
      :steps => [
        'I enable more Tails Greeter options',
        'I enable Microsoft Windows camouflage',
        'I enable the specific Tor configuration option',
        'I log in to a new session',
        'Tails Greeter has dealt with the sudo password',
        'the Tails desktop is ready',
        'all notifications have disappeared',
      ],
    },

    'no-network-logged-in-sudo-passwd' => {
      :temporary => true,
      :description => "Tails has booted from DVD without network and logged in with an administration password",
      :parent_checkpoint => "tails-greeter",
      :steps => [
        'I enable more Tails Greeter options',
        'I set an administration password',
        'I log in to a new session',
        'Tails Greeter has dealt with the sudo password',
        'the Tails desktop is ready',
      ],
    },

    'with-network-logged-in-sudo-passwd' => {
      :temporary => true,
      :description => "Tails has booted from DVD and logged in with an administration password and the network is connected",
      :parent_checkpoint => "no-network-logged-in-sudo-passwd",
      :steps => [
        'the network is plugged',
        'Tor is ready',
        'all notifications have disappeared',
        'available upgrades have been checked',
      ],
    },

    'usb-install-tails-greeter' => {
      :description => "Tails has booted without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen" ,
      :parent_checkpoint => 'no-network-logged-in',
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

    'usb-install-with-persistence-tails-greeter' => {
      :description => "Tails has booted without network from a USB drive with a persistent partition and stopped at Tails Greeter's login screen",
      :parent_checkpoint => 'usb-install-tails-greeter',
      :steps => [
        'I log in to a new session',
        'the Tails desktop is ready',
        'I create a persistent partition',
        'a Tails persistence partition exists on USB drive "current"',
        'I shutdown Tails and wait for the computer to power off',
        'I start Tails from USB drive "current" with network unplugged',
        'the boot device has safe access rights',
        'Tails is running from USB drive "current"',
      ],
    },

    'usb-install-with-persistence-logged-in' => {
      :description => "Tails has booted without network from a USB drive with a persistent partition enabled and logged in",
      :parent_checkpoint => 'usb-install-with-persistence-tails-greeter',
      :steps => [
        'I enable persistence',
        'I log in to a new session',
        'the Tails desktop is ready',
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
  red = 31
  green = 32
  def colorize(color_code, s)
    "\e[#{color_code}m#{s}\e[0m"
  end

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
    STDERR.puts(scenario_indent + "Checkpoint: #{checkpoint_description}")
    step_action = "Given"
    if parent_checkpoint
      parent_description = checkpoints[parent_checkpoint][:description]
      STDERR.puts(
        step_indent +
        colorize(green, "#{step_action} #{parent_description}"))
      step_action = "And"
    end
    steps.each do |s|
      begin
        step(s)
      rescue Exception => e
        STDERR.puts(
          scenario_indent +
          colorize(red, "Step failed while creating checkpoint: #{s}"))
        raise e
      end
      STDERR.puts(step_indent + colorize(green, "#{step_action} #{s}"))
      step_action = "And"
    end
    $vm.save_snapshot(name)
  end
end

# For each checkpoint we generate a step to reach it.
checkpoints.each do |name, desc|
  step_regex = Regexp.new("^#{desc[:description]}$")
  Given step_regex do
    reach_checkpoint(name)
  end
end

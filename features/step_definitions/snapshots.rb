CHECKPOINTS =
  {
    'tails-greeter'                              => {
      description:       "I have started Tails from DVD without network and stopped at Tails Greeter's login screen",
      parent_checkpoint: nil,
      steps:             [
        'the network is unplugged',
        'I start the computer',
        'the computer boots Tails',
      ],
    },

    'no-network-logged-in'                       => {
      description:       'I have started Tails from DVD without network and logged in',
      parent_checkpoint: 'tails-greeter',
      steps:             [
        'I log in to a new session',
        'all notifications have disappeared',
      ],
    },

    'with-network-logged-in'                     => {
      description:       'I have started Tails from DVD and logged in and the network is connected',
      parent_checkpoint: 'no-network-logged-in',
      steps:             [
        'the network is plugged',
        'Tor is ready',
        'all notifications have disappeared',
        'available upgrades have been checked',
      ],
    },

    'no-network-logged-in-sudo-passwd'           => {
      temporary:         true,
      description:       'I have started Tails from DVD without network and logged in with an administration password',
      parent_checkpoint: 'tails-greeter',
      steps:             [
        'I set an administration password',
        'I log in to a new session',
        'all notifications have disappeared',
      ],
    },

    'with-network-logged-in-sudo-passwd'         => {
      temporary:         true,
      description:       'I have started Tails from DVD and logged in with an administration password and the network is connected',
      parent_checkpoint: 'no-network-logged-in-sudo-passwd',
      steps:             [
        'the network is plugged',
        'Tor is ready',
        'all notifications have disappeared',
        'available upgrades have been checked',
      ],
    },

    'no-network-logged-in-unsafe-browser'        => {
      temporary:         true,
      description:       'I have started Tails from DVD without network and logged in with the Unsafe Browser enabled',
      parent_checkpoint: 'tails-greeter',
      steps:             [
        'I allow the Unsafe Browser to be started',
        'I log in to a new session',
        'all notifications have disappeared',
      ],
    },

    'with-network-logged-in-unsafe-browser'      => {
      temporary:         true,
      description:       'I have started Tails from DVD and logged in with the Unsafe Browser enabled and the network is connected',
      parent_checkpoint: 'no-network-logged-in-unsafe-browser',
      steps:             [
        'the network is plugged',
        'Tor is ready',
        'all notifications have disappeared',
        'available upgrades have been checked',
      ],
    },

    'usb-install-tails-greeter'                  => {
      description:       "I have started Tails without network from a USB drive without a persistent partition and stopped at Tails Greeter's login screen",
      parent_checkpoint: nil,
      steps:             [
        'I create a 7200 MiB disk named "__internal"',
        'I plug USB drive "__internal"',
        'I write the Tails USB image to disk "__internal"',
        'I start Tails from USB drive "__internal" with network unplugged',
        'the boot device has safe access rights',
        'Tails is running from USB drive "__internal"',
        'there is no persistence partition on USB drive "__internal"',
        'process "udev-watchdog" is running',
        'udev-watchdog is monitoring the correct device',
      ],
    },

    'usb-install-logged-in'                      => {
      description:       'I have started Tails without network from a USB drive without a persistent partition and logged in',
      parent_checkpoint: 'usb-install-tails-greeter',
      steps:             [
        'I log in to a new session',
        'all notifications have disappeared',
      ],
    },

    'usb-install-with-persistence-tails-greeter' => {
      description:       "I have started Tails without network from a USB drive with a persistent partition and stopped at Tails Greeter's login screen",
      parent_checkpoint: 'usb-install-logged-in',
      steps:             [
        'I create a persistent partition',
        'a Tails persistence partition exists on USB drive "__internal"',
        'I cold reboot the computer',
        'the computer reboots Tails',
        'the boot device has safe access rights',
        'Tails is running from USB drive "__internal"',
        'process "udev-watchdog" is running',
        'udev-watchdog is monitoring the correct device',
      ],
    },

    'usb-install-with-persistence-logged-in'     => {
      description:       'I have started Tails without network from a USB drive with a persistent partition enabled and logged in',
      parent_checkpoint: 'usb-install-with-persistence-tails-greeter',
      steps:             [
        'I enable persistence',
        'I log in to a new session',
        'all persistence presets are enabled',
        'all persistent filesystems have safe access rights',
        'all persistence configuration files have safe access rights',
        'all persistent directories have safe access rights',
        'all notifications have disappeared',
      ],
    },

  }.freeze

# XXX: giving up on a few worst offenders for now
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
def reach_checkpoint(name)
  scenario_indent = ' ' * 4
  step_indent = ' ' * 6

  step 'a computer'
  if VM.snapshot_exists?(name)
    $vm.restore_snapshot(name)
  else
    checkpoint = CHECKPOINTS[name]
    checkpoint_description = checkpoint[:description]
    parent_checkpoint = checkpoint[:parent_checkpoint]
    steps = checkpoint[:steps]
    if parent_checkpoint
      if VM.snapshot_exists?(parent_checkpoint)
        $vm.restore_snapshot(parent_checkpoint)
      else
        reach_checkpoint(parent_checkpoint)
      end
      post_snapshot_restore_hook(parent_checkpoint)
    end
    debug_log(scenario_indent + "Checkpoint: #{checkpoint_description}",
              color: :white, timestamp: false)
    step_action = 'Given'
    if parent_checkpoint
      parent_description = CHECKPOINTS[parent_checkpoint][:description]
      debug_log(step_indent + "#{step_action} #{parent_description}",
                color: :green, timestamp: false)
      step_action = 'And'
    end
    steps.each do |s|
      begin
        step(s)
      rescue StandardError => e
        debug_log(scenario_indent +
                  "Step failed while creating checkpoint: #{s}",
                  color: :red, timestamp: false)
        raise e
      end
      debug_log(step_indent + "#{step_action} #{s}",
                color: :green, timestamp: false)
      step_action = 'And'
    end
    $vm.save_snapshot(name)
  end
  # VM#save_snapshot restores the RAM-only snapshot immediately
  # after saving it, in which case post_snapshot_restore_hook is
  # useful to ensure we've reached a good starting point, so we run
  # it in all cases, including even when've just saved a new snapshot.
  post_snapshot_restore_hook(name)
end
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength

# For each checkpoint we generate a step to reach it.
CHECKPOINTS.each do |name, desc|
  step_regex = Regexp.new("^#{Regexp.escape(desc[:description])}$")
  Given step_regex do
    begin
      reach_checkpoint(name)
    rescue StandardError => e
      debug_log("    Generated snapshot step failed with exception:\n" \
                "      #{e.class}: #{e}\n", color: :red, timestamp: false)
      raise e
    end
  end
end

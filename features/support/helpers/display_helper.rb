
class Display

  def initialize(domain, x_display)
    @domain = domain
    @x_display = x_display
  end

  def active?
    p = IO.popen("xprop -display #{@x_display} " +
                 "-name '#{@domain} (1) - Virt Viewer' 2>/dev/null")
    Process.wait(p.pid)
    $?.success?
  end

  def start
    @virtviewer = IO.popen(["virt-viewer", "-d",
                                           "-f",
                                           "-r",
                                           "-c", "qemu:///system",
                                           ["--display=", @x_display].join(''),
                                           @domain].join(' '))
    # We wait for the display to be active to not lose actions
    # (e.g. key presses via sikuli) that come immediately after
    # starting (or restoring) a vm
    try_for(20, { :delay => 0.1, :msg => "virt-viewer failed to start"}) {
      active?
    }
  end

  def stop
    Process.kill("INT", @virtviewer.pid)
  end

  def restart
    stop
    start
  end

end


class Display

  def initialize(domain, x_display)
    @domain = domain
    @x_display = x_display
  end

  def active?
    p = IO.popen(["xprop", "-display", @x_display,
                  "-name", "#{@domain} (1) - Virt Viewer",
                  :err => ["/dev/null", "w"]])
    Process.wait(p.pid)
    $?.success?
  end

  def start
    @virtviewer = IO.popen(["virt-viewer", "--direct",
                                           "--kiosk",
                                           "--reconnect",
                                           "--connect", "qemu:///system",
                                           "--display", @x_display,
                                           @domain,
                                           :err => ["/dev/null", "w"]])
    # We wait for the display to be active to not lose actions
    # (e.g. key presses via sikuli) that come immediately after
    # starting (or restoring) a vm
    try_for(20, { :delay => 0.1, :msg => "virt-viewer failed to start"}) {
      active?
    }
  end

  def stop
    return if @virtviewer.nil?
    Process.kill("TERM", @virtviewer.pid)
    @virtviewer.close
  rescue IOError
    # IO.pid throws this if the process wasn't started yet. Possibly
    # there's a race when doing a start() and then quickly running
    # stop().
  end

  def restart
    stop
    start
  end

end


class Display

  def initialize(domain)
    @domain = domain
  end

  def start
    start_virtviewer(@domain)
  end

  def stop
    stop_virtviewer
  end

  def restart
    stop_virtviewer
    start_virtviewer(@domain)
  end

  # We could use libvirt functionality to take a screenshot (e.g.
  # `virsh -c qemu:///system screenshot TailsToaster`) but with
  # this approach we see the same exact same display as sikuli,
  # which could help debug future DISPLAY problems.
  def take_screenshot(description)
    IO.popen(["xwd", "-display",
                     ENV['DISPLAY'],
                     "-root",
                     "-out", description + ".xwd"].join(' '))
    IO.popen("convert " + description + ".xwd " + description + ".png")
    IO.popen("rm " + description + ".xwd")
    puts("Took screenshot \"" + description + ".png\"")
  end

  def start_virtviewer(domain)
    # virt-viewer forks, so we cannot (easily) get the child pid
    # and use it in active? and stop_virtviewer below...
    IO.popen(["virt-viewer", "-d",
                             "-f",
                             "-r",
                             "-c", "qemu:///system",
                             ["--display=", ENV['DISPLAY']].join(''),
                             domain,
                             "&"].join(' '))
  end

  def active?
    system("pkill -0 virt-viewer")
  end

  def stop_virtviewer
    system("killall virt-viewer")
  end
end

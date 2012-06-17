
class Display

  def initialize(domain)
    start_virtviewer(domain)
  end

  def stop
    stop_virtviewer
  end

  # Self-explainatory TODO item. Xvfb can be told to put screen raw X images
  # in a directory. These files are .wxd that can prob. be converted. see Xvfb(1)
  def take_screenshot

  end

  def start_virtviewer(domain)
    IO.popen(["virt-viewer", "-d",
                             "-f",
                             "-r",
                             "-c", "qemu+ssh://localhost/system",
                             ["--display=", ENV['DISPLAY']].join(''),
                             domain,
                             "&"].join(' '))
  end

  def stop_virtviewer
    system("killall virt-viewer")
  end
end

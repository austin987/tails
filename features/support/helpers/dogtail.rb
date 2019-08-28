module Dogtail
  module Mouse
    LEFT_CLICK = 1
    MIDDLE_CLICK = 2
    RIGHT_CLICK = 3
  end

  TREE_API_NODE_SEARCHES = [
    :button,
    :child,
    :childLabelled,
    :childNamed,
    :dialog,
    :menu,
    :menuItem,
    :panel,
    :tab,
    :textentry,
  ]

  TREE_API_NODE_SEARCH_FIELDS = [
    :labelee,
    :parent,
  ]

  TREE_API_NODE_ACTIONS = [
    :click,
    :doubleClick,
    :grabFocus,
    :keyCombo,
    :point,
    :typeText,
  ]

  TREE_API_APP_SEARCHES = TREE_API_NODE_SEARCHES + [
    :dialog,
    :window,
  ]

  # We want to keep this class immutable so that handles always are
  # left intact when doing new (proxied) method calls.  This way we
  # can support stuff like:
  #
  #     app = Dogtail::Application.new('gedit')
  #     menu = app.menu('Menu')
  #     menu.click()
  #     menu.something_else()
  #     menu.click()
  #
  # i.e. the object referenced by `menu` is never modified by method
  # calls and can be used as expected.

  class Application
    @@node_counter ||= 0

    def initialize(app_name, opts = {})
      @var = "node#{@@node_counter += 1}"
      @app_name = app_name
      @opts = opts
      @opts[:user] ||= LIVE_USER
      @find_code = "dogtail.tree.root.application('#{@app_name}')"
      script_lines = [
        "import dogtail.config",
        "import dogtail.tree",
        "import dogtail.predicate",
        "import dogtail.rawinput",
        "dogtail.config.logDebugToFile = False",
        "dogtail.config.logDebugToStdOut = False",
        "dogtail.config.blinkOnActions = True",
        "dogtail.config.searchShowingOnly = True",
        "#{@var} = #{@find_code}",
      ]
      run(script_lines)
    end

    def to_s
      @var
    end

    def run(code)
      code = code.join("\n") if code.class == Array
      c = RemoteShell::PythonCommand.new($vm, code, user: @opts[:user])
      if c.failure?
        raise RuntimeError.new("The Dogtail script raised: #{c.exception}")
      end
      return c
    end

    def child?(*args)
      !!child(*args)
    rescue
      false
    end

    def exist?
      run("dogtail.config.searchCutoffCount = 0")
      run(@find_code)
      return true
    rescue
      return false
    ensure
      run("dogtail.config.searchCutoffCount = 20")
    end

    def self.value_to_s(v)
      if v == true
        'True'
      elsif v == false
        'False'
      elsif v.class == String
        "'#{v}'"
      elsif [Fixnum, Float].include?(v.class)
        v.to_s
      else
        raise "#{self.class.name} does not know how to handle argument type '#{v.class}'"
      end
    end

    # Generates a Python-style parameter list from `args`. If the last
    # element of `args` is a Hash, it's used as Python's kwargs dict.
    # In the end, the resulting string should be possible to copy-paste
    # into the parentheses of a Python function call.
    # Example: [42, {:foo => 'bar'}] => "42, foo = 'bar'"
    def self.args_to_s(args)
      return "" if args.size == 0
      args_list = args
      args_hash = nil
      if args_list.class == Array && args_list.last.class == Hash
        *args_list, args_hash = args_list
      end
      (
        (args_list.nil? ? [] : args_list.map { |e| self.value_to_s(e) }) +
        (args_hash.nil? ? [] : args_hash.map { |k, v| "#{k}=#{self.value_to_s(v)}" })
      ).join(', ')
    end

    # Equivalent to the Tree API's Node.findChildren(), with the
    # arguments constructing a GenericPredicate to use as parameter.
    def children(*args)
      non_predicates = [:recursive, :showingOnly]
      findChildren_opts = []
      findChildren_opts_hash = Hash.new
      if args.last.class == Hash
        args_hash = args.last
        non_predicates.each do |opt|
          if args_hash.has_key?(opt)
            findChildren_opts_hash[opt] = args_hash[opt]
            args_hash.delete(opt)
          end
        end
      end
      findChildren_opts = ""
      if findChildren_opts_hash.size > 0
        findChildren_opts = ", " + self.class.args_to_s([findChildren_opts_hash])
      end
      predicate_opts = self.class.args_to_s(args)
      nodes_var = "nodes#{@@node_counter += 1}"
      find_script_lines = [
        "#{nodes_var} = #{@var}.findChildren(dogtail.predicate.GenericPredicate(#{predicate_opts})#{findChildren_opts})",
        "print(len(#{nodes_var}))",
      ]
      size = run(find_script_lines).stdout.chomp.to_i
      return size.times.map do |i|
        Node.new("#{nodes_var}[#{i}]", @opts)
      end
    end

    def get_field(key)
      run("print(#{@var}.#{key})").stdout.chomp
    end

    def set_field(key, value)
      run("#{@var}.#{key} = #{self.class.value_to_s(value)}")
    end

    def text
      get_field('text')
    end

    def text=(value)
      set_field('text', value)
    end

    def name
      get_field('name')
    end

    def roleName
      get_field('roleName')
    end

    # Note: this is a global Dogtail action, which should probably live
    # elsewhere than in our Application class, but currently we lack
    # the infrastructure to do that: the Ruby plumbing that generates
    # and runs Python code lives in the Application class.
    def pressKey(key)
      # Dogtail will prefix the value of key with 'KEY_'
      # and the result must be a valid Gdk key symbol such as Gdk.KEY_Down
      run("dogtail.rawinput.pressKey('#{key}')")
    end

    TREE_API_APP_SEARCHES.each do |method|
      define_method(method) do |*args|
        args_str = self.class.args_to_s(args)
        method_call = "#{method.to_s}(#{args_str})"
        Node.new("#{@var}.#{method_call}", @opts)
      end
    end

    TREE_API_NODE_SEARCH_FIELDS.each do |field|
      define_method(field) do
        Node.new("#{@var}.#{field}", @opts)
      end
    end

  end

  class Node < Application

    def initialize(expr, opts = {})
      @expr = expr
      @opts = opts
      @opts[:user] ||= LIVE_USER
      @find_code = expr
      @var = "node#{@@node_counter += 1}"
      run("#{@var} = #{@find_code}")
    end

    TREE_API_NODE_SEARCHES.each do |method|
      define_method(method) do |*args|
        args_str = self.class.args_to_s(args)
        method_call = "#{method.to_s}(#{args_str})"
        Node.new("#{@var}.#{method_call}", @opts)
      end
    end

    TREE_API_NODE_ACTIONS.each do |method|
      define_method(method) do |*args|
        args_str = self.class.args_to_s(args)
        method_call = "#{method.to_s}(#{args_str})"
        run("#{@var}.#{method_call}")
      end
    end

  end
end

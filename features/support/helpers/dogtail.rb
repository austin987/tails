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
    :tab,
    :textentry,
  ]

  TREE_API_NODE_SEARCH_FIELDS = [
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
  # calls and can be used as expected. This explains why
  # `proxy_call()` below returns a new instance instead of adding
  # appending the new component the proxied method call would result
  # in.

  class Application

    def initialize(app_name, opts = {})
      @app_name = app_name
      @opts = opts
      @init_lines = @opts[:init_lines] || [
        "from dogtail import tree",
        "from dogtail.config import config",
        "config.logDebugToFile = False",
        "config.logDebugToStdOut = False",
        "config.blinkOnActions = True",
        "config.searchShowingOnly = True",
        "application = tree.root.application('#{@app_name}')",
      ]
      @components = @opts[:components] || ['application']
    end

    def build_script(lines)
      (
        ["#!/usr/bin/python"] +
        @init_lines +
        lines
      ).join("\n")
    end

    def build_line
      @components.join('.')
    end

    def run(lines = nil)
      @opts[:user] ||= LIVE_USER
      lines ||= [build_line]
      lines = [lines] if lines.class != Array
      script = build_script(lines)
      script_path = $vm.execute_successfully('mktemp', @opts).stdout.chomp
      $vm.file_overwrite(script_path, script, @opts[:user])
      args = ["/usr/bin/python '#{script_path}'", @opts]
      if @opts[:allow_failure]
        ret = $vm.execute(*args)
      else
        ret = $vm.execute_successfully(*args)
      end
      $vm.execute("rm -f '#{script_path}'")
      ret
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

    def wait(timeout = nil)
      if timeout
        try_for(timeout) { run }
      else
        run
      end
    end

    def exist?
      @opts[:allow_failure] = true
      # We do not want any retries since this method should return the
      # result for the immediate situation, not for the situation up
      # to 20 retries in the future.
      optimization = "config.searchCutoffCount = 1"
      @init_lines << optimization unless @init_lines.include?(optimization)
      run.success?
    end

    def wait_vanish(timeout)
      try_for(timeout) { not(exist?) }
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
      # A fundamental assumption of ScriptProxy is that we will only
      # act on *one* object at a time. If we were to allow more, we'd
      # have to port looping, conditionals and much more into our
      # script generation, which is insane.
      # However, since references are lost between script runs (=
      # Application.run()) we need to be a bit tricky here. We use the
      # internal a11y AT-SPI "path" to uniquely identify a Dogtail
      # node, so we can give handles to each of them that can be used
      # later to re-find them.
      predicate_opts = self.class.args_to_s(args)
      find_paths_script_lines = [
        "from dogtail import predicate",
        "for n in #{build_line}.findChildren(predicate.GenericPredicate(#{predicate_opts})#{findChildren_opts}):",
        "    print(n.path)",
      ]
      a11y_at_spi_paths = run(find_paths_script_lines).stdout.chomp.split("\n")
                          .grep(Regexp.new('^/org/a11y/atspi/accessible/'))
                          .map { |path| path.chomp }
      a11y_at_spi_paths.map do |path|
        more_init_lines = [
          "from dogtail import predicate",
          "node = None",
          "for n in #{build_line}.findChildren(predicate.GenericPredicate()):",
          "    if str(n.path) == '#{path}':",
          "        node = n",
          "        break",
          "assert(node)",
        ]
        Node.new(
          @app_name,
          @opts.merge(
            init_lines: @init_lines + more_init_lines,
            components: ['node']
          )
        )
      end
    end

    def get_field(key)
      run("print(#{build_line}.#{key})").stdout.chomp
    end

    def set_field(key, value)
      run("#{build_line}.#{key} = #{self.class.value_to_s(value)}")
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

    def proxy_call(method, args)
      args_str = self.class.args_to_s(args)
      method_call = "#{method.to_s}(#{args_str})"
      Node.new(
        @app_name,
        @opts.merge(
          init_lines: @init_lines,
          components: @components + [method_call]
        )
      )
    end

    TREE_API_APP_SEARCHES.each do |method|
      define_method(method) do |*args|
        proxy_call(method, args)
      end
    end

    TREE_API_NODE_SEARCH_FIELDS.each do |field|
      define_method(field) do
        Node.new(
          @app_name,
          @opts.merge(
            init_lines: @init_lines,
            components: @components + [field]
          )
        )
      end
    end

  end

  class Node < Application

    TREE_API_NODE_SEARCHES.each do |method|
      define_method(method) do |*args|
        proxy_call(method, args)
      end
    end

    TREE_API_NODE_ACTIONS.each do |method|
      define_method(method) do |*args|
        proxy_call(method, args).run
      end
    end

  end
end

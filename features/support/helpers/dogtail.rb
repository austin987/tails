module Dogtail
  module Mouse
    LEFT_CLICK = 1
    MIDDLE_CLICK = 2
    RIGHT_CLICK = 3
  end

  # We want to keep this class immutable so that handles always are
  # left intact when doing new (proxied) method calls.  This was we
  # can support stuff like:
  #
  #     Dogtail::Application.interact('gedit') do |app|
  #         menu = app.menu('Menu')
  #         menu.click()
  #         menu.something_else()
  #         menu.click()
  #     end
  #
  # i.e. the object referenced by `menu` is never modified by method
  # calls and can be used as expected. This explains why
  # `proxy_call()` below returns a new instance instead of adding
  # appending the new component the proxied method call would result
  # in.

  class ScriptProxy

    def initialize(init_lines = [], init_components = [], opts = {})
      @module_import_lines = []
      @init_lines = init_lines
      @opts = opts
      @components = init_components
    end

    def build_script(lines)
      (
        ["#!/usr/bin/python"] +
        @module_import_lines +
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
        $vm.execute(*args)
      else
        $vm.execute_successfully(*args)
      end
    ensure
      $vm.execute("rm -f '#{script_path}'")
    end

    def self.args_to_s(args)
      args_list = args
      args_hash = nil
      if args_list.class == Array && args_list.last.class == Hash
        *args_list, args_hash = args_list
      end
      argify = Proc.new do |v|
        if v == true
          'True'
        elsif v == false
          'False'
        elsif v.class == String
          "\"#{v}\""
        elsif [Fixnum, Float].include?(v.class)
          v.to_s
        else
          raise "#{self.class.name} does not know how to handle argument type '#{v.class}'"
        end
      end
      (
        (args_list.nil? ? [] : args_list.map { |e| argify.call(e) }) +
        (args_hash.nil? ? [] : args_hash.map { |k, v| "#{k}=#{argify.call(v)}" })
      ).join(', ')
    end

    def proxy_call(method, args)
      args_str = self.class.args_to_s(args)
      component = "#{method.to_s}(#{args_str})"
      final_components = @components + [component]
      self.class.new(@init_lines, final_components,  @opts)
    end

    def get_field(key)
      run("print(#{build_line}.#{key})").stdout
    end
  end

  TREE_API_NODE_ACTIONS = [
    :click,
    :doubleClick,
    :grabFocus,
    :keyCombo,
    :point,
    :typeText,
  ]

  TREE_API_NODE_SEARCHES = [
    :button,
    :child,
    :childLabelled,
    :childNamed,
    :dialog,
    :menu,
    :menuItem,
    :tab,
    :text,
    :textentry,
    :window,
  ]

  TREE_API_NODE_METHODS = (TREE_API_NODE_ACTIONS + TREE_API_NODE_SEARCHES)

  class TreeAPIScriptProxy < ScriptProxy

    def initialize(*args)
      super(*args)
      @module_import_lines += [
        'from dogtail import tree',
        'from dogtail.config import config',
      ]
      @module_import_lines.uniq!
      @init_lines = ['config.searchShowingOnly = True'] + @init_lines
      @init_lines.uniq!
    end

    TREE_API_NODE_METHODS.each do |method|
      define_method(method) do |*args|
        proxy = proxy_call(method, args)
        # If it's not an action we are calling, we just want a
        # "reference" for use later, so we just return ScriptProxy
        # object representing the current state of the call.
        TREE_API_NODE_ACTIONS.include?(method) ? proxy.run : proxy
      end
    end

    def wait(timeout = nil)
      if timeout
        try_for(timeout) { run }
      else
        run
      end
    end

  end

  LOCAL_TREE_API_NODE_METHODS = [
    :wait,
    :get_field,
  ]

  ALL_TREE_API_NODE_METHODS = TREE_API_NODE_METHODS + LOCAL_TREE_API_NODE_METHODS

  class Application

    def initialize(app)
      @app = app
    end

    def self.init_lines(app)
      ["application = tree.root.application(\"#{app}\")"]
    end

    def self.init_components
      ['application']
    end

    def self.interact(app, opts = {}, &block)
      yield TreeAPIScriptProxy.new(self.init_lines(app),
                                   self.init_components,
                                   opts)
    end

    def interact(*args, &block)
      self.class.interact(@app, *args, &block)
    end

    ALL_TREE_API_NODE_METHODS.each do |method|
      define_method(method) do |*args|
        interact do |app|
          app.method(method).call(*args)
        end
      end
    end

  end
end

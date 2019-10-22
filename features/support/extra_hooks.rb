# Now that we stopped supporting Cucumber<2.0, we could probably do
# this differently.

begin
  if not(Cucumber::Core::Ast::Feature.instance_methods.include?(:accept_hook?))
    require 'cucumber/core/gherkin/tag_expression'
    class Cucumber::Core::Ast::Feature
      # Code inspired by Cucumber::Core::Test::Case.match_tags?() in
      # cucumber-ruby-core 1.1.3, lib/cucumber/core/test/case.rb:~59.
      def accept_hook?(hook)
        tag_expr = Cucumber::Core::Gherkin::TagExpression.new(hook.tag_expressions.flatten)
        tag_expr.evaluate(@tags)
      end
    end
  end
rescue NameError => e
  raise e if e.to_s != "uninitialized constant Cucumber::Core"
end

# Sort of inspired by Cucumber::RbSupport::RbHook (from cucumber
# < 2.0) but really we just want an object with a 'tag_expressions'
# attribute to make accept_hook?() (used below) happy.
class SimpleHook
  attr_reader :tag_expressions

  def initialize(tag_expressions, proc)
    @tag_expressions = tag_expressions
    @proc = proc
  end

  def invoke(arg)
    @proc.call(arg)
  end
end

def BeforeFeature(*tag_expressions, &block)
  $before_feature_hooks ||= []
  $before_feature_hooks << SimpleHook.new(tag_expressions, block)
end

def AfterFeature(*tag_expressions, &block)
  $after_feature_hooks ||= []
  $after_feature_hooks << SimpleHook.new(tag_expressions, block)
end

require 'cucumber/formatter/console'
if not($at_exit_print_artifacts_dir_patching_done)
  module Cucumber::Formatter::Console
    if method_defined?(:print_stats)
      alias old_print_stats print_stats
    end
    def print_stats(*args)
      @io.puts "Artifacts directory: #{ARTIFACTS_DIR}"
      @io.puts
      @io.puts "Debug log:           #{ARTIFACTS_DIR}/debug.log"
      @io.puts
      if self.class.method_defined?(:old_print_stats)
        old_print_stats(*args)
      end
    end
  end
  $at_exit_print_artifacts_dir_patching_done = true
end

def info_log(message = "", options = {})
  options[:color] = :clear
  # This trick allows us to use a module's (~private) method on a
  # one-off basis.
  cucumber_console = Class.new.extend(Cucumber::Formatter::Console)
  puts cucumber_console.format_string(message, options[:color])
end

def debug_log(message, options = {})
  options[:timestamp] = true unless options.has_key?(:timestamp)
  if $debug_log_fns
    if options[:timestamp]
      # Force UTC so the local timezone difference vs UTC won't be
      # added to the result.
      elapsed = (Time.now - TIME_AT_START.to_f).utc.strftime("%H:%M:%S.%9N")
      message = "#{elapsed}: #{message}"
    end
    $debug_log_fns.each { |fn| fn.call(message, options) }
  end
end

require 'cucumber/formatter/pretty'

module ExtraFormatters
  # This is a null formatter in the sense that it doesn't ever output
  # anything. We only use it do hook into the correct events so we can
  # add our extra hooks.
  class ExtraHooks
    def initialize(runtime, io, options)
      # We do not care about any of the arguments.
      # XXX: We should be able to just have `*args` for the arguments
      # in the prototype, but since moving to cucumber 2.4 that breaks
      # this formatter for some unknown reason.
    end

    def before_feature(feature)
      if $before_feature_hooks
        $before_feature_hooks.each do |hook|
          hook.invoke(feature) if feature.accept_hook?(hook)
        end
      end
    end

    def after_feature(feature)
      if $after_feature_hooks
        $after_feature_hooks.reverse.each do |hook|
          hook.invoke(feature) if feature.accept_hook?(hook)
        end
      end
    end
  end

  # The pretty formatter with debug logging mixed into its output.
  class PrettyDebug < Cucumber::Formatter::Pretty
    def initialize(runtime, io, options)
      super(runtime, io, options)
      $debug_log_fns ||= []
      $debug_log_fns << self.method(:debug_log)
    end

    def debug_log(message, options)
      options[:color] ||= :blue
      @io.puts(format_string(message, options[:color]))
      @io.flush
    end
  end

end

module Cucumber
  module Cli
    class Options
      BUILTIN_FORMATS['pretty_debug'] =
        [
          'ExtraFormatters::PrettyDebug',
          'Prints the feature with debugging information - in colours.'
        ]
      BUILTIN_FORMATS['debug'] = BUILTIN_FORMATS['pretty_debug']
    end
  end
end

AfterConfiguration do |config|
  # Cucumber may read this file multiple times, and hence run this
  # AfterConfiguration hook multiple times. We only want our
  # ExtraHooks formatter to be loaded once, otherwise the hooks would
  # be run miltiple times.
  extra_hooks = [
    ['ExtraFormatters::ExtraHooks', '/dev/null'],
    ['Cucumber::Formatter::Pretty', "#{ARTIFACTS_DIR}/pretty.log"],
    ['Cucumber::Formatter::Json', "#{ARTIFACTS_DIR}/cucumber.json"],
    ['ExtraFormatters::PrettyDebug', "#{ARTIFACTS_DIR}/debug.log"],
  ]
  extra_hooks.each do |hook|
    config.formats << hook if not(config.formats.include?(hook))
  end
end

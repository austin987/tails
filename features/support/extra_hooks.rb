# Make the code below work with cucumber >= 2.0. Once we stop
# supporting <2.0 we should probably do this differently, but this way
# we can easily support both at the same time.
begin
  if not(Cucumber::Core::Ast::Feature.instance_methods.include?(:accept_hook?))
    require 'gherkin/tag_expression'
    class Cucumber::Core::Ast::Feature
      # Code inspired by Cucumber::Core::Test::Case.match_tags?() in
      # cucumber-ruby-core 1.1.3, lib/cucumber/core/test/case.rb:~59.
      def accept_hook?(hook)
        tag_expr = Gherkin::TagExpression.new(hook.tag_expressions.flatten)
        tags = @tags.map do |t|
          Gherkin::Formatter::Model::Tag.new(t.name, t.line)
        end
        tag_expr.evaluate(tags)
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
      if Dir.exists?(ARTIFACTS_DIR) and Dir.entries(ARTIFACTS_DIR).size > 2
        @io.puts "Artifacts directory: #{ARTIFACTS_DIR}"
        @io.puts
      end
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
  $debug_log_fns.each { |fn| fn.call(message, options) } if $debug_log_fns
end

require 'cucumber/formatter/pretty'
# Backport part of commit af940a8 from the cucumber-ruby repo. This
# fixes the "out hook output" for the Pretty formatter so stuff
# written via `puts` after a Scenario has run its last step will be
# written, instead of delayed to the next Feature/Scenario (if any) or
# dropped completely (if not).
# XXX: This can be removed once we stop supporting Debian Jessie
# around when Debian Stretch is released.
if Gem::Version.new(Cucumber::VERSION) < Gem::Version.new('2.0.0.beta.4')
  module Cucumber
    module Formatter
      class Pretty
        def after_feature_element(feature_element)
          print_messages
          @io.puts
          @io.flush
        end
      end
    end
  end
end

module ExtraFormatters
  # This is a null formatter in the sense that it doesn't ever output
  # anything. We only use it do hook into the correct events so we can
  # add our extra hooks.
  class ExtraHooks
    def initialize(*args)
      # We do not care about any of the arguments.
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
    def initialize(*args)
      super(*args)
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
  extra_hooks = ['ExtraFormatters::ExtraHooks', '/dev/null']
  config.formats << extra_hooks if not(config.formats.include?(extra_hooks))
end

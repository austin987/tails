require 'cucumber/formatter/pretty'

# Sort of inspired by Cucumber::RbSupport::RbHook, but really we just
# want an object with a 'tag_expressions' attribute to make
# accept_hook?() (used below) happy.
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

module ExtraHooks
  class Pretty < Cucumber::Formatter::Pretty
    def before_feature(feature)
      for hook in $before_feature_hooks do
        hook.invoke(feature) if feature.accept_hook?(hook)
      end
      super if defined?(super)
    end

    def after_feature(feature)
      for hook in $after_feature_hooks do
        hook.invoke(feature) if feature.accept_hook?(hook)
      end
      super if defined?(super)
    end
  end
end

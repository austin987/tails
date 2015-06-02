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

AfterConfiguration do |config|
  # Cucumber may read this file multiple times, and hence run this
  # AfterConfiguration hook multiple times. Patching the formatter
  # more than once will lead to problems, so let's ensure we only do
  # it once.
  next if $formatters_are_patched
  # Multiple formatters can be registered, but we only patch one of
  # them, since we only want our hooks to run once in total, not once
  # for each formatter.
  formatter_name, _ = config.formats.first
  formatter = config.formatter_class(formatter_name)
  formatter.class_exec do
    if method_defined?(:before_feature)
      alias old_before_feature before_feature
    end

    def before_feature(feature)
      if $before_feature_hooks
        $before_feature_hooks.each do |hook|
          hook.invoke(feature) if feature.accept_hook?(hook)
        end
      end
      if self.class.method_defined?(:old_before_feature)
        old_before_feature(feature)
      end
    end

    if method_defined?(:after_feature)
      alias old_after_feature after_feature
    end

    def after_feature(feature)
      if self.class.method_defined?(:old_after_feature)
        old_after_feature(feature)
      end
      if $after_feature_hooks
        $after_feature_hooks.each do |hook|
          hook.invoke(feature) if feature.accept_hook?(hook)
        end
      end
    end
  end
  $formatters_are_patched = true
end

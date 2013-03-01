require 'cucumber/formatter/pretty'

def BeforeFeature(&block)
  $before_feature_hook = block
end

def AfterFeature(&block)
  $after_feature_hook = block
end

module ExtraHooks
  class Pretty < Cucumber::Formatter::Pretty
    def before_feature(feature)
      $before_feature_hook.call(feature) if $before_feature_hook
      super if defined?(super)
    end

    def after_feature(feature)
      $after_feature_hook.call(feature) if $after_feature_hook
      super if defined?(super)
    end
  end
end

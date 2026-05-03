# frozen_string_literal: true

# Most of the runner wrapper's interesting behavior lives in private methods.
# Expose them on a one-off subclass so specs can call them directly without
# touching the production class.
def dirty_dirty_unprivate_class(klass)
  Class.new(klass) do
    (private_instance_methods - Class.private_instance_methods).each do |method|
      eval <<-RUBY
        def #{method}(...)
          super
        end
      RUBY
    end
  end
end

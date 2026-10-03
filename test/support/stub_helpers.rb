# Minimal class-method stubbing (minitest 6 no longer ships minitest/mock).
module StubHelpers
  # Makes `object.method_name` return `value` for the duration of the block.
  # A Proc `value` is called with the method's arguments instead.
  def stub_method(object, method_name, value)
    original = object.method(method_name)
    object.define_singleton_method(method_name) { |*args, **kwargs| value.is_a?(Proc) ? value.call(*args, **kwargs) : value }
    yield
  ensure
    object.define_singleton_method(method_name, original)
  end
end

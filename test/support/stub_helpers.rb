# Minimal class-method stubbing (minitest 6 no longer ships minitest/mock).
module StubHelpers
  # Makes `object.method_name` return `value` for the duration of the block.
  # A Proc `value` is called with the method's arguments instead.
  def stub_method(object, method_name, value)
    restore = replace_method(object, method_name, value)
    yield
  ensure
    restore&.call
  end

  # Same as stub_method, but until the end of the current test.
  def stub_method_until_teardown(object, method_name, value)
    (@restore_stubs ||= []) << replace_method(object, method_name, value)
  end

  def after_teardown
    @restore_stubs&.reverse_each(&:call)
    super
  end

  private

  def replace_method(object, method_name, value)
    original = object.method(method_name)
    object.define_singleton_method(method_name) { |*args, **kwargs| value.is_a?(Proc) ? value.call(*args, **kwargs) : value }
    -> { object.define_singleton_method(method_name, original) }
  end
end

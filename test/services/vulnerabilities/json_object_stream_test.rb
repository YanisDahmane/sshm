require "test_helper"

class Vulnerabilities::JsonObjectStreamTest < ActiveSupport::TestCase
  def members(json, chunk: 7)
    [].tap { |list| Vulnerabilities::JsonObjectStream.each(StringIO.new(json.b), chunk: chunk) { |key, value| list << [ key, value ] } }
  end

  test "yields each member, whatever the chunk boundaries (strings with braces, escapes, accents)" do
    json = %( \n{"a": {"x": "{not} \\"json\\" [é]", "y": [1, {"z": null}]}, "b\\u00e9": 12 ,"c":"ç","d": true}\n)
    expected = [ [ "a", { "x" => "{not} \"json\" [é]", "y" => [ 1, { "z" => nil } ] } ], [ "bé", 12 ], [ "c", "ç" ], [ "d", true ] ]
    [ 1, 2, 3, 7, 64, 1 << 20 ].each { |chunk| assert_equal expected, members(json, chunk: chunk), "chunk #{chunk}" }
  end

  test "the real tracker extract reads the same as JSON.parse" do
    json = file_fixture("vulnerabilities/debian_tracker.json").read
    assert_equal JSON.parse(json).to_a, members(json, chunk: 5)
  end

  test "an empty object, a truncated document, something else" do
    assert_empty members("{}")
    assert_raises(Vulnerabilities::JsonObjectStream::Error) { members(%({"a": {"b": 1)) }
    assert_raises(Vulnerabilities::JsonObjectStream::Error) { members("[1, 2]") }
    assert_raises(Vulnerabilities::JsonObjectStream::Error) { members("") }
  end
end

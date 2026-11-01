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

  test "streams the elements of a top-level array (NVD feeds)" do
    json = %({"format": "NVD_CVE", "vulnerabilities": [{"cve": {"id": "CVE-1", "d": "[é]"}}, {"cve": {"id": "CVE-2"}} ], "after": 1})
    [ 1, 3, 1 << 20 ].each do |chunk|
      ids = []
      Vulnerabilities::JsonObjectStream.each_element(StringIO.new(json.b), key: "vulnerabilities", chunk: chunk) { |item| ids << item.dig("cve", "id") }
      assert_equal %w[CVE-1 CVE-2], ids, "chunk #{chunk}"
    end
    assert_raises(Vulnerabilities::JsonObjectStream::Error) { Vulnerabilities::JsonObjectStream.each_element(StringIO.new("{}"), key: "vulnerabilities") { } }
  end
end

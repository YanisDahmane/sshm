require "test_helper"

class PaginatorTest < ActiveSupport::TestCase
  test "pages an array" do
    pager = Paginator.new((1..23).to_a, page: "2", per_page: 10)

    assert_equal (11..20).to_a, pager.records
    assert_equal [ 3, 2, 1, 3 ], [ pager.pages, pager.page, pager.previous_page, pager.next_page ]
    assert_equal [ 11, 20, 23 ], [ pager.from, pager.to, pager.total ]
    assert pager.multiple_pages?
  end

  test "pages a relation, counting it once" do
    pager = Paginator.new(Server.order(:name), page: 2, per_page: 2)
    assert_equal [ "Web" ], pager.records.map(&:name)
    assert_equal [ 3, 2, nil ], [ pager.total, pager.pages, pager.next_page ]
  end

  test "a missing, invalid or too big page" do
    assert_equal 1, Paginator.new([ 1, 2 ], page: nil, per_page: 1).page
    assert_equal 1, Paginator.new([ 1, 2 ], page: "abc", per_page: 1).page
    assert_equal 1, Paginator.new([ 1, 2 ], page: "-4", per_page: 1).page
    last = Paginator.new([ 1, 2 ], page: "99", per_page: 1)
    assert_equal [ 2, [ 2 ] ], [ last.page, last.records ]
  end

  test "an empty list has one page" do
    pager = Paginator.new([], page: 1, per_page: 10)
    assert_equal [ 1, 0, 0, [] ], [ pager.pages, pager.from, pager.to, pager.records ]
    assert_not pager.multiple_pages?
  end

  test "series of page numbers with gaps" do
    series = ->(page, pages) { Paginator.new((1..pages).to_a, page: page, per_page: 1).series }
    assert_equal [ 1, 2, 3 ], series.(1, 3)
    assert_equal [ 1, 2, 3, :gap, 20 ], series.(1, 20)
    assert_equal [ 1, :gap, 8, 9, 10, 11, 12, :gap, 20 ], series.(10, 20)
    assert_equal [ 1, 2, 3, 4, 5, 6, :gap, 20 ], series.(4, 20)
    assert_equal [ 1, :gap, 18, 19, 20 ], series.(20, 20)
  end
end

# One page of a list (an Active Record relation or an array): the records,
# the number of pages and the page numbers to show (1 … 4 5 6 … 20). A page
# beyond the last one shows the last one. See the shared/_pagination partial.
class Paginator
  attr_reader :page, :per_page, :total

  def initialize(collection, page:, per_page:)
    @collection = collection
    @per_page = per_page
    @total = collection.is_a?(Array) ? collection.size : collection.count(:all)
    @page = page.to_i.clamp(1, pages)
  end

  def records
    @records ||= if @collection.is_a?(Array)
      @collection.slice(offset, per_page) || []
    else
      @collection.offset(offset).limit(per_page).to_a
    end
  end

  def pages = [ (total.to_f / per_page).ceil, 1 ].max
  def offset = (page - 1) * per_page
  def multiple_pages? = pages > 1
  def previous_page = page > 1 ? page - 1 : nil
  def next_page = page < pages ? page + 1 : nil

  # Position of the first / last record of the page (1-based), 0 when empty.
  def from = total.zero? ? 0 : offset + 1
  def to = [ offset + per_page, total ].min

  # Page numbers around the current one, with :gap for the skipped ones.
  def series(around: 2)
    numbers = ([ 1, pages ] + ((page - around)..(page + around)).to_a).select { |number| number.between?(1, pages) }.uniq.sort
    numbers.each_with_object([]) do |number, series|
      series << :gap if series.any? && number - series.last > 1
      series << number
    end
  end
end

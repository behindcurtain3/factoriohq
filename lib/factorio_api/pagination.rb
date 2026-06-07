module FactorioApi
  class Pagination
    attr_reader :current
    attr_reader :size
    attr_reader :count
    attr_reader :first
    attr_reader :next
    attr_reader :prev
    attr_reader :last

    def initialize(json_data)
      @current = json_data["pagination"]["page"]
      @size = json_data["pagination"]["page_size"]
      @count = json_data["pagination"]["page_count"]
      @first = parse_link(json_data["pagination"]["links"]["first"])
      @next = parse_link(json_data["pagination"]["links"]["next"])
      @prev = parse_link(json_data["pagination"]["links"]["prev"])
      @last = parse_link(json_data["pagination"]["links"]["last"])
    end

    private

    def parse_link(link)
      return link if link.nil?
      return 1 unless link.include?("page=")

      uri = URI(link)
      params = CGI.parse(uri.query || "")

      page_param = params["page"]&.first
      page_param&.to_i
    end
  end
end

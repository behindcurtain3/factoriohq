module FactorioApi
  class Response
    attr_reader :pagination
    attr_reader :results

    def initialize(json_data)
      # Parse the JSON data and initialize the results and pagination
      @results = []
      json_data["results"].each do |mod_data|
        @results << Mod.new(mod_data)
      end
      @pagination = Pagination.new(json_data)
    end
  end
end

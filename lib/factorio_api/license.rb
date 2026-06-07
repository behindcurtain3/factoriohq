module FactorioApi
  class License
    attr_reader :id
    attr_reader :name
    attr_reader :description
    attr_reader :url
    attr_reader :title

    def initialize(license_data)
      @id = license_data.fetch("id", "")
      @name = license_data.fetch("name", "")
      @description = license_data.fetch("description", "")
      @url = license_data.fetch("url", "")
      @title = license_data.fetch("title", "")
    end
  end
end

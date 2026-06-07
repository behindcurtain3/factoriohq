module FactorioApi
  class Release
    attr_reader :download_url
    attr_reader :file_name
    attr_reader :info_json
    attr_reader :released_at
    attr_reader :version
    attr_reader :sha1

    def initialize(release_data)
      @download_url = release_data.fetch("download_url", nil)
      @file_name = release_data.fetch("file_name", nil)
      @info_json = release_data.fetch("info_json", nil)
      @released_at = DateTime.iso8601(release_data.fetch("released_at")) if release_data.key?("released_at")
      @version = release_data.fetch("version", nil)
      @sha1 = release_data.fetch("sha1", nil)
    end
  end
end

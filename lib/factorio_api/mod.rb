module FactorioApi
  class Mod
    attr_reader :name
    attr_reader :downloads_count
    attr_reader :owner
    attr_reader :summary
    attr_reader :title
    attr_reader :category
    attr_reader :score
    attr_reader :thumbnail
    attr_reader :changelog
    attr_reader :created_at
    attr_reader :updated_at
    attr_reader :last_highlighted_at
    attr_reader :description
    attr_reader :source_url
    attr_reader :homepage
    attr_reader :tags
    attr_reader :license
    attr_reader :deprecated
    attr_reader :latest_release
    attr_reader :releases

    def initialize(mod_data)
      raise ArgumentError, "Name is required" unless mod_data.key?("name")

      # Always present fields
      @name = mod_data.fetch("name")
      @downloads_count = mod_data.fetch("downloads_count", 0)
      @owner = mod_data.fetch("owner", "")
      @summary = mod_data.fetch("summary", "")
      @title = mod_data.fetch("title", "")
      @category = mod_data.fetch("category", "")
      @score = mod_data.fetch("score", 0)

      # Only on full mod data
      @thumbnail = mod_data.fetch("thumbnail", nil)
      @changelog = mod_data.fetch("changelog", nil)
      @created_at = DateTime.iso8601(mod_data.fetch("created_at")) if mod_data.key?("created_at")
      @updated_at = DateTime.iso8601(mod_data.fetch("updated_at")) if mod_data.key?("updated_at")
      @last_highlighted_at = DateTime.iso8601(mod_data.fetch("last_highlighted_at")) if mod_data.key?("last_highlighted_at")
      @description = mod_data.fetch("description", nil)
      @source_url = mod_data.fetch("source_url", nil)
      @homepage = mod_data.fetch("homepage", nil)
      @tags = mod_data.fetch("tags", [])
      @license = License.new(mod_data.fetch("license")) if mod_data.key?("license")
      @deprecated = mod_data.fetch("deprecated", false)

      # Releases
      @latest_release = Release.new(mod_data.fetch("latest_release")) if mod_data.key?("latest_release")
      @releases = []
      if mod_data.key?("releases")
        mod_data["releases"].each do |release_data|
          @releases << Release.new(release_data)
        end
      end

      # Sort releases by released_at in descending order
      @releases = @releases.sort_by(&:released_at).reverse
      @latest_release = @releases.first if @latest_release.nil? && !@releases.empty?
    end
  end
end

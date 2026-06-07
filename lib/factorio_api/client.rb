require "digest/sha1"

module FactorioApi
  class Client
    API_URL = "https://mods.factorio.com/api/mods"
    DOWNLOAD_URL = "https://mods.factorio.com"

    def self.get_mods(page = 1, page_size = 25, hide_deprecated = true, namelist = "")
      uri = URI(API_URL)

      # Query parameters
      params = {
        page: page,
        page_size: page_size,
        hide_deprecated: hide_deprecated
      }

      # Only add namelist if it's not empty
      params[:namelist] = namelist if namelist.present?

      # Add parameters to URI
      uri.query = URI.encode_www_form(params)

      puts uri

      Response.new(JSON.parse(Net::HTTP.get(uri)))
    end

    def self.get_mod(mod_name)
      uri = URI(API_URL + "/#{mod_name}/full")

      Mod.new(JSON.parse(Net::HTTP.get(uri)))
    end

    def self.download_mod(download_url, username, token, output_path)
      url = URI(DOWNLOAD_URL + "#{download_url}?username=#{username}&token=#{token}")

      Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == "https") do |http|
        request = Net::HTTP::Get.new(url)

        http.request(request) do |response|
          case response
          when Net::HTTPFound
            # Follow the redirect
            redirect_url = URI(response["location"])
            req = Net::HTTP::Get.new(redirect_url)

            # Start the sha1 hashing
            sha1 = Digest::SHA1.new

            Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true) do |http2|
              http2.request(req) do |res|
                File.open(output_path, "wb") do |file|
                  res.read_body do |chunk|
                    file.write(chunk)
                    sha1.update(chunk)
                  end
                end
              end
            end

            return { success: true, sha1: sha1.hexdigest }
          else
            raise "Failed to download mod: #{response.code} #{response.message}"
          end
        end
      end
    end
  end
end

require "net/http"
require "json"

# == Schema Information
#
# Table name: factorio_servers
#
#  id                     :bigint           not null, primary key
#  name                   :string           not null
#  description            :text
#  port                   :integer          default(34197), not null
#  rcon_port              :integer          default(27015), not null
#  rcon_password          :string
#  max_players            :integer          default(0)
#  game_password          :string
#  admin_password         :string
#  auto_start             :boolean          default(FALSE)
#  docker_container_id    :string
#  status                 :string           default("stopped")
#  version                :string           default("latest")
#  save_file              :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :bigint           not null
#
class FactorioServer < ApplicationRecord
  broadcasts_refreshes
  belongs_to :user, touch: true
  has_many :mods, dependent: :destroy
  has_many :server_logs, dependent: :destroy
  has_many :game_logs, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :port, presence: true,
                  numericality: { greater_than: 1024, less_than: 65535 },
                  uniqueness: true
  validates :rcon_port, presence: true,
                       numericality: { greater_than: 1024, less_than: 65535 },
                       uniqueness: true
  validate :validate_save_file

  # Default values
  attribute :port, :integer, default: 34197
  attribute :rcon_port, :integer, default: 27015
  attribute :max_players, :integer, default: 0
  attribute :auto_start, :boolean, default: false
  attribute :status, :string, default: "stopped"
  attribute :visibility_public, :boolean, default: false
  attribute :visibility_lan, :boolean, default: true
  attribute :require_user_verification, :boolean, default: true
  attribute :max_upload_in_kilobytes_per_second, :integer, default: 0
  attribute :max_upload_slots, :integer, default: 5
  attribute :minimum_latency_in_ticks, :integer, default: 0
  attribute :ignore_player_limit_for_returning_players, :boolean, default: false
  attribute :allow_commands, :string, default: "admins-only"
  attribute :autosave_interval, :integer, default: 10
  attribute :autosave_slots, :integer, default: 5
  attribute :afk_autokick_interval, :integer, default: 0
  attribute :auto_pause, :boolean, default: true
  attribute :only_admins_can_pause_the_game, :boolean, default: true
  attribute :autosave_only_on_server, :boolean, default: true
  attribute :non_blocking_saving, :boolean, default: false
  attribute :minimum_segment_size, :integer, default: 25
  attribute :minimum_segment_size_peer_count, :integer, default: 20
  attribute :maximum_segment_size, :integer, default: 100
  attribute :maximum_segment_size_peer_count, :integer, default: 10
  attribute :token, :string, default: ""
  attribute :tags, :string, default: "factoriohq"
  attribute :auto_update_mods, :boolean, default: false

  # Statuses
  enum :status, {
    stopped: "stopped",
    starting: "starting",
    running: "running",
    stopping: "stopping",
    error: "error"
  }

  # Callbacks
  before_validation :generate_passwords, on: :create
  after_create :create_server_directory
  after_create :update_mod_list
  after_update :update_mod_list

  # Docker container names and on-disk data are namespaced by Rails environment.
  # This keeps multiple instances that share a single Docker daemon and
  # FACTORIO_DATA_PATH (e.g. running production and development side by side) from
  # managing the same container or save directory. Production is left unprefixed
  # for backwards compatibility with existing containers and data.
  def self.namespace
    Rails.env.production? ? nil : Rails.env.to_s
  end

  # Instance methods
  def server_directory
    root = ENV["FACTORIO_DATA_PATH"]
    root = "#{root}/#{self.class.namespace}" if self.class.namespace
    "#{root}/servers/#{id}"
  end

  def saves_directory
    "#{server_directory}/saves"
  end

  def mods_directory
    "#{server_directory}/mods"
  end

  def config_file_path
    "#{server_directory}/config/server-settings.json"
  end

  def mod_list_path
    "#{mods_directory}/mod-list.json"
  end

  def admin_list_path
    "#{server_directory}/config/server-adminlist.json"
  end

  # The factoriotools image reads the RCON password from this file (and would
  # otherwise generate a random one we don't know). Writing it lets us control
  # the password so the app can authenticate to RCON.
  def rconpw_path
    "#{server_directory}/config/rconpw"
  end

  # Factorio admin usernames parsed from the free-text field. Accepts commas,
  # whitespace, or newlines as separators.
  def admin_list
    admin_usernames.to_s.split(/[\s,]+/).map(&:strip).reject(&:blank?).uniq
  end

  def start
    return false if running?

    update(status: "starting")
    ServerOperationJob.perform_later(self, "start")
    true
  end

  def stop
    return false unless running?

    update(status: "stopping")
    ServerOperationJob.perform_later(self, "stop")
    true
  end

  def restart
    if running?
      stop
      # Wait for server to stop
      sleep 2 until stopped?
    end
    start
  end

  def running?
    status == "running"
  end

  def stopped?
    status == "stopped"
  end

  def container_exists?
    Docker::Container.get(docker_container_id)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def container_name
    ns = self.class.namespace
    ns ? "factorio-#{ns}-server-#{id}" : "factorio-server-#{id}"
  end

  def server_settings
    # Generate server settings JSON for Factorio
    {
      name: name,
      description: description,
      tags: tags.present? ? tags.split : [ "managed" ],
      max_players: max_players,
      visibility: {
        public: visibility_public,
        lan: visibility_lan
      },
      username: user.factorio_username.nil? ? "" : user.factorio_username,
      password: "",
      token: token.nil? ? "" : token,
      game_password: game_password,
      require_user_verification: require_user_verification,
      max_upload_in_kilobytes_per_second: max_upload_in_kilobytes_per_second,
      max_upload_slots: max_upload_slots,
      minimum_latency_in_ticks: minimum_latency_in_ticks,
      ignore_player_limit_for_returning_players: ignore_player_limit_for_returning_players,
      allow_commands: allow_commands,
      autosave_interval: autosave_interval,
      autosave_slots: autosave_slots,
      afk_autokick_interval: afk_autokick_interval,
      auto_pause: auto_pause,
      only_admins_can_pause_the_game: only_admins_can_pause_the_game,
      autosave_only_on_server: autosave_only_on_server,
      non_blocking_saving: non_blocking_saving,
      minimum_segment_size: minimum_segment_size,
      minimum_segment_size_peer_count: minimum_segment_size_peer_count,
      maximum_segment_size: maximum_segment_size,
      maximum_segment_size_peer_count: maximum_segment_size_peer_count
    }
  end

  def update_mod_list
    UpdateModListJob.perform_later(self)
  end

  def get_mod_list
    mod_list = get_default_mods_list
    mods.each do |mod|
      mod_list << {
        name: mod.name,
        enabled: mod.enabled
      }
    end

    {
      mods: mod_list
    }
  end

  def get_default_mods_list
    [
      {
        name: "base",
        enabled: enable_base
      },
      {
        name: "elevated-rails",
        enabled: enable_elevated_rails
      },
      {
        name: "quality",
        enabled: enable_quality
      },
      {
        name: "space-age",
        enabled: enable_space_age
      }
    ]
  end

  # The Docker image repository used to run game servers. Configurable by the
  # site owner so a mirror or a drop-in-compatible fork can be used instead of
  # the default factoriotools image. A custom image must accept the same env
  # vars, mount /factorio, and use the same version tag scheme.
  DEFAULT_IMAGE_REPOSITORY = "factoriotools/factorio".freeze

  def self.image_repository
    SiteSetting.get("factorio_image_repository").presence || DEFAULT_IMAGE_REPOSITORY
  end

  # Cleans owner-supplied input: blank -> default, and strips an accidental
  # ":tag" from the image name (we always append the version ourselves).
  def self.normalize_image_repository(value)
    value = value.to_s.strip
    return DEFAULT_IMAGE_REPOSITORY if value.blank?

    segments = value.split("/")
    segments[-1] = segments[-1].split(":").first if segments[-1].include?(":")
    segments.join("/")
  end

  # Returns the Docker Hub "owner/name" when the repository lives on Docker Hub
  # (so its tags can be listed via the Hub API), or nil for custom registries
  # whose first path segment carries a host ("." or ":", e.g. ghcr.io).
  def self.docker_hub_repository
    repo = image_repository
    first_segment = repo.split("/").first
    return nil if first_segment&.match?(/[.:]/)

    repo
  end

  def image_reference(tag = nil)
    tag = tag.presence || version.presence || "latest"
    "#{self.class.image_repository}:#{tag}"
  end

  def self.available_versions
    # Cache the versions for 1 hour, keyed by repository so changing it refetches.
    Rails.cache.fetch("factorio_versions/#{image_repository}", expires_in: 1.hour) do
      repo = docker_hub_repository
      # Custom registries can't be enumerated through the Docker Hub API.
      next [ "latest" ] unless repo

      begin
        # Fetch tags from Docker Hub API
        uri = URI("https://hub.docker.com/v2/repositories/#{repo}/tags?page_size=100")
        response = Net::HTTP.get(uri)
        data = JSON.parse(response)

        # Extract and sort versions
        versions = data["results"].map { |tag| tag["name"] }

        # Filter out non-version tags and sort properly
        version_regex = /^(\d+\.\d+\.\d+)$/
        version_tags = versions.select { |v| v.match(version_regex) || v == "latest" }

        # Put 'latest' at the top, then sort versions in descending order
        [ "latest" ] + version_tags.reject { |v| v == "latest" }.sort_by do |v|
          v.split(".").map(&:to_i)
        end.reverse
      rescue => e
        # Fallback to a minimal list if the API call fails
        Rails.logger.error "Failed to fetch Factorio versions for #{repo}: #{e.message}"
        [
          "latest"
        ]
      end
    end
  end

  def check_for_updates
    return unless docker_container_id.present?

    begin
      # Pull the latest image
      latest_image = Docker::Image.create("fromImage" => image_reference("latest"))

      # Get current image ID
      container = Docker::Container.get(docker_container_id)
      current_image_id = container.info["Image"]

      # Compare image IDs
      if latest_image.id != current_image_id && version == "latest"
        return {
          update_available: true,
          current_id: current_image_id,
          latest_id: latest_image.id
        }
      end
    rescue => e
      return { error: e.message }
    end

    { update_available: false }
  end

  def update_version(new_version)
    # Can only update if server is stopped
    return { success: false, message: "Server must be stopped to update version" } unless stopped?

    old_version = version || "latest"

    # Update the version
    if update(version: new_version)
      server_logs.create(
        level: "info",
        message: "Version changed from #{old_version} to #{new_version}",
        timestamp: Time.current
      )
      { success: true, message: "Version updated to #{new_version}" }
    else
      { success: false, message: errors.full_messages.join(", ") }
    end
  end

  def create_server_directory
    # Create the server directory if it doesn't exist
    FileUtils.mkdir_p(server_directory)
    FileUtils.mkdir_p(saves_directory)
    FileUtils.mkdir_p(mods_directory)
    FileUtils.mkdir_p(File.dirname(config_file_path))

    UpdateModListJob.perform_later(self)
  end

  private

  def generate_passwords
    self.rcon_password ||= SecureRandom.hex(12)
    self.game_password ||= SecureRandom.hex(8) if game_password.blank?
    self.admin_password ||= SecureRandom.hex(10)
  end

  def validate_save_file
    return if save_file.blank?

    if save_file.include?("/") || save_file.include?("\\")
      errors.add(:save_file, "cannot contain path separators")
    end

    unless save_file.end_with?(".zip")
      errors.add(:save_file, "must have .zip extension")
    end
  end
end

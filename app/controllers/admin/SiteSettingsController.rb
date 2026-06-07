class Admin::SiteSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  def index
    @registration_enabled = SiteSetting.get("registrations_enabled", "true") == "true"
    @factorio_image_repository = FactorioServer.image_repository
  end

  def update
    if params.key?(:registrations_enabled)
      SiteSetting.set("registrations_enabled", params[:registrations_enabled] == "1" ? "true" : "false")
    end

    if params.key?(:factorio_image_repository)
      repo = FactorioServer.normalize_image_repository(params[:factorio_image_repository])
      SiteSetting.set("factorio_image_repository", repo)
      Rails.cache.delete("factorio_versions/#{repo}")
    end

    redirect_to admin_site_settings_path, notice: "Settings updated successfully"
  end

  private

  def ensure_admin
    redirect_to root_path, alert: "Access denied" unless current_user.admin?
  end
end

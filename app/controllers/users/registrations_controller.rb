class Users::RegistrationsController < Devise::RegistrationsController
  before_action :check_registrations_enabled, only: [:new, :create]

  private

  def check_registrations_enabled
    unless SiteSetting.get('registrations_enabled', 'true') == 'true'
      flash[:alert] = '<i class="bi bi-exclamation-triangle-fill me-2"></i>New registrations are currently disabled.'.html_safe
      redirect_to new_user_session_path
    end
  end
end
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_minimum_password_length

  def edit
  end

  def update
    if current_user.update(user_params)
      redirect_to edit_user_path, notice: "Settings updated successfully."
    else
      flash.now[:alert] = "Failed to update settings."
      render :edit
    end
  end

  def update_password
    if current_user.update_with_password(password_params)
      bypass_sign_in(current_user)
      redirect_to edit_user_path, notice: "Password changed successfully."
    else
      flash.now[:alert] = "Failed to change password."
      render :edit
    end
  end

  private

  def user_params
    params.require(:user).permit(:factorio_token, :factorio_username)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end

  def set_minimum_password_length
    @minimum_password_length = Devise.password_length.min
  end
end

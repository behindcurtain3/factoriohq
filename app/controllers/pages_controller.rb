class PagesController < ApplicationController
  def home
    redirect_to factorio_servers_path if user_signed_in?
  end
end

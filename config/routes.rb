Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations"
  }

  resources :factorio_servers do
    resources :save_files, only: [ :index, :create ] do
      collection do
        get ":filename", to: "save_files#show", constraints: { filename: /[^\/]+/ }, as: :download
        delete ":filename", to: "save_files#destroy", constraints: { filename: /[^\/]+/ }, as: :delete
        post ":filename/set_as_current", to: "save_files#set_as_current", constraints: { filename: /[^\/]+/ }, as: :set_current
      end
    end

    member do
      post :start
      post :stop
      post :restart
      get :check_updates
      patch :update_version
      post :console
    end
    resources :server_logs, only: [ :index ]
    resources :game_logs, only: [ :index ]
    resources :mods, only: [ :index, :create, :destroy ], as: :server_mods, controller: "server_mods"
  end

  resources :mods, only: [ :index, :show, :create ] do
    patch :toggle, on: :member
  end
  resources :users, only: [ :edit, :update ] do
    member do
      patch :update_password
    end
  end

  namespace :admin do
    get "site_settings", to: "site_settings#index"
    patch "site_settings", to: "site_settings#update"
  end

  root to: "factorio_servers#index"
end

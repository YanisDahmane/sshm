Rails.application.routes.draw do
  devise_for :users

  resources :servers do
    resource :ping, only: :create, controller: "server_pings"
    resource :ssh_check, only: :create, controller: "server_ssh_checks"
    resources :authorized_keys, only: :index, controller: "server_authorized_keys"
    resource :authorized_key, only: :destroy, controller: "server_authorized_keys"
    resources :authorizations, only: :create, controller: "server_authorizations"
  end
  resource :server_pings, only: :create, path: "servers/pings"
  resource :server_scans, only: :create, path: "servers/scans"

  resources :profiles do
    resources :accesses, only: :create, controller: "profile_accesses"
    resource :access, only: :destroy, controller: "profile_accesses"
  end

  resource :settings, only: :show
  namespace :settings do
    resource :notifications, only: :show
    resources :notification_channels, except: %i[index show], path: "notifications/channels" do
      post :test, on: :member
    end
    resources :automations, only: %i[index update] do
      post :run, on: :member
    end
  end
  resources :activities, only: :index
  scope "settings" do
    resource :ssh_key, only: :create
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"
end

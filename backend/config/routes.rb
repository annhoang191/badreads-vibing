Rails.application.routes.draw do
  # Load balancer / uptime check (Rails default, no DB).
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :health, only: :show, controller: "health"
      resources :registrations, only: :create
      resource :session, only: %i[create destroy]
      resource :me, only: :show, controller: "me"
      resources :imports, only: %i[index show create]
      resources :books, only: :index
    end
  end
end

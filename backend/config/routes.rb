Rails.application.routes.draw do
  # Load balancer / uptime check (Rails default, no DB).
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :health, only: :show, controller: "health"
    end
  end
end

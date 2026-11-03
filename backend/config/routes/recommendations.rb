# Routes for the recommendations area (drawn inside namespace api/v1).
resources :recommendations, only: :index do
  post :generate, on: :collection
end
resources :recommendation_batches, only: :show

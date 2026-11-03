# Routes for the insights area (drawn inside namespace api/v1).
resource :insights, only: :show do
  post :refresh
end

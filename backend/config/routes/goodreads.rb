# Routes for the goodreads area (drawn inside namespace api/v1).
resource :goodreads_profile, only: %i[show update] do
  post :sync
end

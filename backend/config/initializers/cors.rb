# Allow the Vue dev server (and the deployed frontend) to call the API.
# Set FRONTEND_ORIGINS to a comma-separated list in production.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("FRONTEND_ORIGINS", "http://localhost:5173").split(","))

    resource "*",
      headers: :any,
      expose: [ "Authorization" ],
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end

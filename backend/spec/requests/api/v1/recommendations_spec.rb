require "rails_helper"

RSpec.describe "Recommendations API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:body) { response.parsed_body }

  def rate_books(count)
    create_list(:user_book, count, user:, my_rating: 4)
  end

  describe "GET /api/v1/recommendations" do
    it "returns 401 without a token" do
      get "/api/v1/recommendations"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns a null batch and full quota with no batches" do
      get "/api/v1/recommendations", headers: headers

      expect(response).to have_http_status(:ok)
      expect(body).to eq("batch" => nil, "quota" => { "limit" => 5, "remaining" => 5, "resets_at" => nil })
    end

    it "returns the latest completed batch with ordered recommendations" do
      create(:recommendation_batch, user:, status: "completed", created_at: 2.days.ago)
      batch = create(:recommendation_batch, user:, status: "completed", ranked_by: "agent")
      (1..10).to_a.shuffle.each do |pos|
        book = create(:book, original_publication_year: (1990 if pos == 1), year_published: 2001,
                             open_library_work_key: ("/works/OL1W" if pos == 1))
        create(:recommendation, recommendation_batch: batch, user:, book:, position: pos, score: 90 - pos)
      end

      get "/api/v1/recommendations", headers: headers

      expect(body["batch"]).to include("id" => batch.id, "status" => "completed", "ranked_by" => "agent", "error_message" => nil)
      recs = body["batch"]["recommendations"]
      expect(recs.pluck("position")).to eq((1..10).to_a)
      expect(recs.first).to include("score" => 89, "status" => "new", "reason" => "Shares themes with books you loved.")
      expect(recs.first.keys).to match_array(%w[id position score status reason book])
      expect(recs.first["book"]).to include("year" => 1990, "open_library_url" => "https://openlibrary.org/works/OL1W")
      expect(recs.first["book"].keys).to match_array(%w[id title author year num_pages cover_url open_library_url])
      expect(recs.second["book"]).to include("year" => 2001, "open_library_url" => nil)
      expect(body["quota"]).to include("remaining" => 4)
    end

    it "returns empty recommendations for a non-completed batch" do
      create(:recommendation_batch, user:, status: "failed", error_message: "boom")

      get "/api/v1/recommendations", headers: headers

      expect(body["batch"]).to include("status" => "failed", "error_message" => "boom", "recommendations" => [])
    end
  end

  describe "POST /api/v1/recommendations/generate" do
    it "returns 401 without a token" do
      post "/api/v1/recommendations/generate"
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a pending batch, enqueues the job and returns the new quota" do
      rate_books(10)

      expect { post "/api/v1/recommendations/generate", headers: headers }
        .to have_enqueued_job(GenerateRecommendationsJob)

      expect(response).to have_http_status(:accepted)
      expect(body["batch"]).to include("status" => "pending", "ranked_by" => nil, "recommendations" => [])
      expect(body["quota"]).to include("limit" => 5, "remaining" => 4, "resets_at" => nil)
      expect(user.recommendation_batches.count).to eq(1)
    end

    it "returns 409 batch_in_progress when a batch is pending or processing" do
      rate_books(10)
      create(:recommendation_batch, user:, status: "processing")

      expect { post "/api/v1/recommendations/generate", headers: headers }
        .not_to have_enqueued_job(GenerateRecommendationsJob)

      expect(response).to have_http_status(:conflict)
      expect(body["error"]["code"]).to eq("batch_in_progress")
    end

    it "returns 422 not_enough_data with details" do
      rate_books(9)
      create(:user_book, user:, my_rating: nil)

      post "/api/v1/recommendations/generate", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(body["error"]).to include("code" => "not_enough_data", "details" => { "required" => 10, "have" => 9 })
    end

    it "returns 429 rate_limited with retry_after once 5 batches exist in 24h" do
      rate_books(10)
      freeze_time do
        create(:recommendation_batch, user:, status: "completed", created_at: 4.hours.ago)
        4.times { create(:recommendation_batch, user:, status: "completed", created_at: 1.hour.ago) }

        post "/api/v1/recommendations/generate", headers: headers

        expect(response).to have_http_status(:too_many_requests)
        expect(body["error"]).to include("code" => "rate_limited", "details" => { "retry_after" => 20.hours.to_i })
      end
    end

    it "counts failed batches toward the quota and reports resets_at" do
      rate_books(10)
      freeze_time do
        oldest = create(:recommendation_batch, user:, status: "failed", created_at: 5.hours.ago)
        4.times { create(:recommendation_batch, user:, status: "failed", created_at: 2.hours.ago) }

        post "/api/v1/recommendations/generate", headers: headers
        expect(response).to have_http_status(:too_many_requests)

        get "/api/v1/recommendations", headers: headers
        expect(body["quota"]).to eq("limit" => 5, "remaining" => 0, "resets_at" => (oldest.created_at + 24.hours).as_json)
      end
    end
  end

  describe "GET /api/v1/recommendation_batches/:id" do
    it "returns 401 without a token" do
      get "/api/v1/recommendation_batches/1"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns the batch" do
      batch = create(:recommendation_batch, user:, status: "completed")
      create(:recommendation, recommendation_batch: batch, user:, position: 1)

      get "/api/v1/recommendation_batches/#{batch.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(body["batch"]).to include("id" => batch.id)
      expect(body["batch"]["recommendations"].size).to eq(1)
    end

    it "returns 404 for another user's batch" do
      other = create(:recommendation_batch)

      get "/api/v1/recommendation_batches/#{other.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end

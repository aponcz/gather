require "rails_helper"

RSpec.describe "Loan fetch required documents", type: :request do
  let!(:company) do
    Company.create!(
      name: "Acme Lending #{SecureRandom.hex(4)}",
      protext_id: "11111111-1111-4111-8111-111111111111"
    )
  end
  let!(:user) do
    User.create!(
      company: company,
      name: "Admin User",
      email: "admin-#{SecureRandom.hex(4)}@acme.test",
      password: "password123",
      role: "admin",
      goprotext_refresh_token: "refresh-token"
    )
  end
  let!(:loan) do
    company.loans.create!(
      title: "Borrower loan",
      created_by: user,
      protext_id: "22222222-2222-4222-8222-222222222222"
    )
  end
  let(:token) { JwtService.encode({ sub: user.id, company_id: company.id, type: "user" }, expires_in: 1.hour) }
  let(:headers) { json_headers("Authorization" => "Bearer #{token}") }

  around do |example|
    original_values = {
      "GOPROTEXT_API_URL" => ENV["GOPROTEXT_API_URL"],
      "GOPROTEXT_OAUTH_CLIENT_ID" => ENV["GOPROTEXT_OAUTH_CLIENT_ID"],
      "GOPROTEXT_OAUTH_CLIENT_SECRET" => ENV["GOPROTEXT_OAUTH_CLIENT_SECRET"],
      "GOPROTEXT_OAUTH_TOKEN_URL" => ENV["GOPROTEXT_OAUTH_TOKEN_URL"]
    }

    ENV["GOPROTEXT_API_URL"] = "https://id.stage.goprotext.com/api/v2"
    ENV["GOPROTEXT_OAUTH_CLIENT_ID"] = "client-id"
    ENV["GOPROTEXT_OAUTH_CLIENT_SECRET"] = "client-secret"
    ENV["GOPROTEXT_OAUTH_TOKEN_URL"] = "https://id.stage.goprotext.com/oauth/token"
    example.run
  ensure
    original_values.each { |key, value| ENV[key] = value }
  end

  def http_success(payload)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, payload.to_json)
    response
  end

  describe "GET /api/v1/loans/:id/fetch_required_documents" do
    it "fetches ProText requirements and adds them to the loan" do
      requests = []
      responses = [
        http_success("access_token" => "oauth-access-token"),
        http_success(
          "general" => [
            {
              "required_documents" => [
                {
                  "key" => "business_assets_listing",
                  "label" => "Complete listing of all business assets"
                }
              ]
            }
          ],
          "guarantors" => [
            {
              "name" => "Ross Demuth",
              "email" => "ross@example.test",
              "required_documents" => [
                {
                  "key" => "drivers_license",
                  "label" => "Enlarged/legible copy of driver's license"
                }
              ]
            },
            {
              "name" => "Kelvin Solomon",
              "required_documents" => [
                {
                  "key" => "drivers_license",
                  "label" => "Enlarged/legible copy of driver's license"
                }
              ]
            }
          ],
          "properties" => [
            {
              "address" => {
                "address_line1" => "7870 Promontory Way",
                "state" => "Utah",
                "city" => "Sandy",
                "zip_code" => "84094"
              },
              "required_documents" => [
                {
                  "key" => "appraisal",
                  "label" => "Appraisal"
                }
              ]
            }
          ]
        )
      ]

      allow_any_instance_of(ProtextDocumentRequirementsService)
        .to receive(:perform_http_request) do |_service, uri, request|
          requests << [uri, request]
          responses.shift
        end

      get "/api/v1/loans/#{loan.id}/fetch_required_documents", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body.slice("fetched_count", "created_count", "skipped_count")).to eq(
        "fetched_count" => 4,
        "created_count" => 4,
        "skipped_count" => 0
      )

      requirements_uri, requirements_request = requests.second
      expect(requirements_uri.to_s).to eq(
        "https://id.stage.goprotext.com/api/v2/loans/#{loan.protext_id}/document_requirements"
      )
      expect(requirements_request["accept"]).to eq("application/json")
      expect(requirements_request["company-id"]).to eq(company.protext_id)
      expect(requirements_request["Authorization"]).to eq("Bearer oauth-access-token")

      expect(loan.request_items.order(:created_at).pluck(:title, :description, :section_name, :required)).to eq([
        ["Complete listing of all business assets", nil, "general", true],
        ["Enlarged/legible copy of driver's license", "Ross Demuth", "guarantors", true],
        ["Enlarged/legible copy of driver's license", "Kelvin Solomon", "guarantors", true],
        ["Appraisal", "7870 Promontory Way, Sandy, Utah 84094", "properties", true]
      ])
      expect(json_body.dig("loan", "request_items").length).to eq(4)
    end

    it "does not add the same requirements twice" do
      loan.request_items.create!(
        title: "Business tax returns",
        description: "Most recent two years",
        section_name: "Financials",
        kind: "document",
        required: true
      )
      allow_any_instance_of(ProtextDocumentRequirementsService)
        .to receive(:perform_http_request)
        .and_return(
          http_success("access_token" => "oauth-access-token"),
          http_success("requirements" => [
            {
              "title" => "Business tax returns",
              "description" => "Most recent two years",
              "section_name" => "Financials"
            }
          ])
        )

      get "/api/v1/loans/#{loan.id}/fetch_required_documents", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_body["created_count"]).to eq(0)
      expect(json_body["skipped_count"]).to eq(1)
      expect(loan.request_items.count).to eq(1)
    end

    it "rejects a loan that is not linked to ProText" do
      loan.update!(protext_id: nil)

      get "/api/v1/loans/#{loan.id}/fetch_required_documents", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body).to include(
        "error" => "protext_document_requirements_fetch_failed",
        "details" => "loan_not_linked_to_protext"
      )
    end
  end
end

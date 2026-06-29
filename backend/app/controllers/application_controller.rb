class ApplicationController < ActionController::API
  include Authentication

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "not_found" }, status: :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { error: "validation_failed", details: error.record.errors.full_messages }, status: :unprocessable_entity
  end
end

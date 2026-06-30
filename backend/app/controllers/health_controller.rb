class HealthController < ActionController::API
  def show
    render json: { status: "ok", service: "gather-backend-rails" }
  end
end

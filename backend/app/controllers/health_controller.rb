class HealthController < ActionController::API
  def show
    render json: { status: "ok", service: "fileinvite-backend-rails" }
  end
end

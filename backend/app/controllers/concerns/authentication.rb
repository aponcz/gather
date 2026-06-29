module Authentication
  extend ActiveSupport::Concern

  included do
    attr_reader :current_user, :current_organization
  end

  def authenticate_user!
    header = request.headers["Authorization"].to_s
    token = header.delete_prefix("Bearer ").presence
    return render(json: { error: "missing_token" }, status: :unauthorized) unless token

    payload = JwtService.decode(token)
    @current_user = User.find(payload.fetch("sub"))
    @current_organization = @current_user.organization
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound, KeyError
    render json: { error: "invalid_token" }, status: :unauthorized
  end

  def authenticate_client!
    header = request.headers["Authorization"].to_s
    token = header.delete_prefix("Bearer ").presence
    return render(json: { error: "missing_token" }, status: :unauthorized) unless token

    payload = JwtService.decode(token)
    return render(json: { error: "wrong_token_type" }, status: :unauthorized) unless payload["type"] == "client"

    @current_contact = Contact.find(payload.fetch("contact_id"))
    @current_organization = @current_contact.organization
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound, KeyError
    render json: { error: "invalid_token" }, status: :unauthorized
  end
end

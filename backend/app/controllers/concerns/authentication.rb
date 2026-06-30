module Authentication
  extend ActiveSupport::Concern

  included do
    attr_reader :current_user, :current_company, :current_membership
  end

  def authenticate_user!
    header = request.headers["Authorization"].to_s
    token = header.delete_prefix("Bearer ").presence
    return render(json: { error: "missing_token" }, status: :unauthorized) unless token

    payload = JwtService.decode(token)
    @current_user = User.find(payload.fetch("sub"))
    requested_company_id = payload["company_id"]
    @current_company = if requested_company_id.present?
      @current_user.companies.find(requested_company_id)
    else
      @current_user.companies.first || @current_user.company
    end
    raise ActiveRecord::RecordNotFound if @current_company.blank?

    @current_membership = @current_user.membership_for(@current_company)
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
    @current_company = @current_contact.company
  rescue JWT::DecodeError, ActiveRecord::RecordNotFound, KeyError
    render json: { error: "invalid_token" }, status: :unauthorized
  end
end

require "net/http"
require "uri"
require "json"

class ProtextLoansImportService
  class Error < StandardError; end

  def initialize(company:, user:, access_token: nil)
    @company = company
    @user = user
    @access_token = access_token
  end

  def call
    access_token = fetch_access_token
    loans = fetch_loans(access_token)

    created_invites = []
    skipped_count = 0

    loans.each do |loan|
      invite = build_invite_from_loan(loan)
      if invite.nil?
        skipped_count += 1
      else
        created_invites << invite
      end
    rescue StandardError => e
      Rails.logger.error("ProText loan import skipped loan due to error: #{e.class}: #{e.message}")
      skipped_count += 1
    end

    {
      fetched_count: loans.length,
      created_count: created_invites.length,
      skipped_count: skipped_count,
      invites: created_invites.map { |invite| { id: invite.id, title: invite.title } }
    }
  end

  private

  attr_reader :company, :user
  attr_reader :access_token

  def fetch_access_token
    return access_token if access_token.present?

    uri = URI(goprotext_token_url)
    request = Net::HTTP::Post.new(uri)

    grant_type = goprotext_token_grant_type
    resolved_grant_type = grant_type
    body = {
      grant_type: resolved_grant_type,
      client_id: goprotext_client_id,
      client_secret: goprotext_client_secret,
      scope: goprotext_scope
    }

    if grant_type == "refresh_token"
      refresh_token = user.goprotext_refresh_token.presence || ENV["GOPROTEXT_OAUTH_REFRESH_TOKEN"].presence
      if refresh_token.present?
        body[:refresh_token] = refresh_token
      else
        resolved_grant_type = "client_credentials"
        body[:grant_type] = resolved_grant_type
      end
    end

    body[:audience] = goprotext_audience if goprotext_audience.present?
    request.set_form_data(body)

    response = perform_http_request(uri, request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("fetch_access_token failed: #{response.code} #{response.message}\nBody: #{response.body}")
      raise Error, "token_request_failed_#{response.code}"
    end

    parsed = JSON.parse(response.body)
    parsed.fetch("access_token")
  rescue KeyError, JSON::ParserError => e
    raise Error, "token_response_invalid: #{e.message}"
  end

  def fetch_loans(access_token)
    all_loans = []
    page = 1

    loop do
      uri = URI(goprotext_loans_url)
      uri.query = URI.encode_www_form(
        page: page,
        per_page: goprotext_loans_per_page,
        state: goprotext_loans_state
      )

      request = Net::HTTP::Get.new(uri)
      request["accept"] = "application/json"
      request["Authorization"] = "Bearer #{access_token}"
      request["company-id"] = goprotext_company_id if goprotext_company_id.present?

      response = perform_http_request(uri, request)

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "loans_request_failed_#{response.code}"
      end

      payload = JSON.parse(response.body)
      loans = extract_loans(payload)
      all_loans.concat(loans)

      break unless more_loans_pages?(payload, loans_count: loans.length, current_page: page)

      page += 1
    end

    all_loans
  rescue JSON::ParserError => e
    raise Error, "loans_response_invalid: #{e.message}"
  end

  def more_loans_pages?(payload, loans_count:, current_page:)
    return false if loans_count.zero?

    if payload.is_a?(Hash)
      next_page = payload["next_page"] || payload.dig("pagination", "next_page")
      return next_page.present? if next_page.present?

      total_pages = payload["total_pages"] || payload.dig("pagination", "total_pages")
      return current_page < total_pages.to_i if total_pages.present?
    end

    loans_count >= goprotext_loans_per_page
  end

  def extract_loans(payload)
    return payload if payload.is_a?(Array)

    loans = payload ["responses"]
    return loans if loans.is_a?(Array)

    []
  end

  def build_invite_from_loan(loan)
    loan_id = loan["id"]

    if loan_id.present? && existing_invite_for_loan_id?(loan_id)
      return nil
    end

    title = build_invite_title(loan)

    Invite.transaction do
      invite = company.invites.create!(
        title: title || "ProText Loan",
        message: "OAuth imported from ProText loan sync.",
        created_by: user,
        contact: nil,
        status: "draft",
        protext_id: loan_id
      )

      invite
    end
  end

  def existing_invite_for_loan_id?(loan_id)
    company.invites.where(protext_id: loan_id).exists?
  end

  def extract_borrower(loan)
    raw = loan["borrower"] || loan[:borrower] || loan["applicant"] || loan[:applicant]
    return raw if raw.is_a?(Hash)

    borrowers = loan["borrowers"] || loan[:borrowers]
    if borrowers.is_a?(Array)
      first = borrowers.first
      return first if first.is_a?(Hash)
    end

    {
      "name" => loan["borrower_name"] || loan[:borrower_name],
      "email" => loan["borrower_email"] || loan[:borrower_email],
      "phone" => loan["borrower_phone"] || loan[:borrower_phone]
    }
  end

  def borrower_name(borrower, email)
    explicit = (borrower["name"] || borrower[:name]).to_s.strip
    return explicit if explicit.present?

    first_name = (borrower["first_name"] || borrower[:first_name]).to_s.strip
    last_name = (borrower["last_name"] || borrower[:last_name]).to_s.strip
    full_name = [first_name, last_name].reject(&:blank?).join(" ").strip
    return full_name if full_name.present?

    email.split("@").first
  end

  def build_invite_title(loan)
    return loan["borrower_name"]
  end

  def build_invite_message(loan, loan_id)
    base = (loan["message"] || loan[:message]).to_s.strip
    marker = loan_id.present? ? "[ProText Loan ID: #{loan_id}]" : "[ProText Loan]"
    [base.presence || "Imported from ProText loan sync.", marker].join("\n")
  end

  def perform_http_request(uri, request)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
  end

  def goprotext_token_url
    ENV.fetch("GOPROTEXT_OAUTH_TOKEN_URL", "https://id.goprotext.com/oauth/token")
  end

  def goprotext_loans_url
    ENV.fetch("GOPROTEXT_LOANS_URL", "https://id.goprotext.com/api/v2/loans")
  end

  def goprotext_client_id
    ENV.fetch("GOPROTEXT_OAUTH_CLIENT_ID")
  end

  def goprotext_client_secret
    ENV.fetch("GOPROTEXT_OAUTH_CLIENT_SECRET")
  end

  def goprotext_scope
    ENV.fetch("GOPROTEXT_OAUTH_SCOPE", "loan_read")
  end

  def goprotext_audience
    ENV["GOPROTEXT_OAUTH_AUDIENCE"]
  end

  def goprotext_token_grant_type
    ENV.fetch("GOPROTEXT_OAUTH_TOKEN_GRANT_TYPE", "refresh_token")
  end

  def goprotext_company_id
    company.protext_id.to_s.presence || ENV["GOPROTEXT_COMPANY_ID"].to_s.presence
  end

  def goprotext_loans_per_page
    ENV.fetch("GOPROTEXT_LOANS_PER_PAGE", "50").to_i
  end

  def goprotext_loans_state
    ENV.fetch("GOPROTEXT_LOANS_STATE", "activated")
  end
end

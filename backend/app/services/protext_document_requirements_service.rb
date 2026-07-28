require "net/http"
require "uri"
require "json"

class ProtextDocumentRequirementsService
  class Error < StandardError; end

  def initialize(loan:, company:, user:, access_token: nil)
    @loan = loan
    @company = company
    @user = user
    @access_token = access_token
  end

  def call
    raise Error, "loan_not_linked_to_protext" if loan.protext_id.blank?
    raise Error, "company_not_linked_to_protext" if goprotext_company_id.blank?

    requirements = fetch_requirements(fetch_access_token)
    created_items = []
    skipped_count = 0

    RequestItem.transaction do
      requirements.each do |requirement|
        attributes = request_item_attributes(requirement)
        if attributes[:title].blank? || existing_request_item?(attributes)
          skipped_count += 1
          next
        end

        created_items << loan.request_items.create!(attributes)
      end
    end

    {
      fetched_count: requirements.length,
      created_count: created_items.length,
      skipped_count: skipped_count
    }
  end

  private

  attr_reader :loan, :company, :user, :access_token

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

    if parsed.key?("refresh_token")
      user.goprotext_refresh_token = parsed.fetch("refresh_token")
      user.save!
    end
    parsed.fetch("access_token")
  rescue KeyError, JSON::ParserError => e
    raise Error, "token_response_invalid: #{e.message}"
  end

  def fetch_requirements(token)
    encoded_loan_id = URI.encode_www_form_component(loan.protext_id.to_s)
    uri = URI("#{goprotext_api_url}/loans/#{encoded_loan_id}/document_requirements")
    request = Net::HTTP::Get.new(uri)
    request["accept"] = "application/json"
    request["company-id"] = goprotext_company_id
    request["Authorization"] = "Bearer #{token}"

    response = perform_http_request(uri, request)
    raise Error, "document_requirements_request_failed_#{response.code}" unless response.is_a?(Net::HTTPSuccess)

    extract_requirements(JSON.parse(response.body))
  rescue JSON::ParserError => e
    raise Error, "document_requirements_response_invalid: #{e.message}"
  end

  def extract_requirements(payload)
    return payload if payload.is_a?(Array)
    return [] unless payload.is_a?(Hash)

    sectioned_requirements = extract_sectioned_requirements(payload)
    return sectioned_requirements if sectioned_requirements.any?

    %w[document_requirements requirements requested_items responses data].each do |key|
      value = payload[key]
      return value if value.is_a?(Array)
      next unless value.is_a?(Hash)

      nested = extract_requirements(value)
      return nested if nested.any?
    end

    []
  end

  def extract_sectioned_requirements(payload)
    payload.flat_map do |section_name, entries|
      next [] unless entries.is_a?(Array)

      entries.each_with_index.flat_map do |entry, entry_index|
        next [] unless entry.is_a?(Hash) && entry["required_documents"].is_a?(Array)

        context = requirement_context(section_name, entry, entry_index)
        entry["required_documents"].filter_map do |document|
          next unless document.is_a?(Hash)

          document.merge(
            "_section_name" => section_name,
            "_context" => context
          )
        end
      end
    end
  end

  def requirement_context(section_name, entry, entry_index)
    return if section_name == "general"

    name_or_email = first_present(entry, "name", "email")
    return name_or_email if name_or_email

    address = entry["address"]
    if address.is_a?(Hash)
      address = address.stringify_keys
      formatted_address = [
        first_present(address, "address_line1"),
        first_present(address, "address_line2"),
        first_present(address, "city"),
        [first_present(address, "state"), first_present(address, "zip_code")].compact.join(" ").presence
      ].compact.join(", ").presence
      return formatted_address if formatted_address
    end

    "#{section_name.to_s.singularize.humanize} #{entry_index + 1}"
  end

  def request_item_attributes(requirement)
    if requirement.is_a?(String)
      return { title: requirement.strip, kind: "document", required: true, section_name: "ProText requirements" }
    end

    value = requirement.respond_to?(:stringify_keys) ? requirement.stringify_keys : {}
    document_type = value["document_type"].is_a?(Hash) ? value["document_type"].stringify_keys : {}
    description = [
      first_present(value, "_context"),
      first_present(value, "description", "instructions", "notes")
    ].compact.join(" — ").presence
    {
      title: first_present(value, "title", "name", "document_name", "document_type_name", "label") ||
        first_present(document_type, "title", "name", "label"),
      description: description,
      kind: "document",
      required: boolean_value(value.key?("required") ? value["required"] : value["is_required"], default: true),
      section_name: first_present(value, "_section_name", "section_name", "category", "group", "document_category") || "ProText requirements"
    }
  end

  def first_present(hash, *keys)
    keys.filter_map { |key| hash[key].to_s.strip.presence }.first
  end

  def boolean_value(value, default:)
    return default if value.nil?
    return value if value == true || value == false

    !%w[false 0 no].include?(value.to_s.downcase)
  end

  def existing_request_item?(attributes)
    loan.request_items.exists?(
      title: attributes[:title],
      description: attributes[:description],
      section_name: attributes[:section_name]
    )
  end

  def perform_http_request(uri, request)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
  end

  def goprotext_api_url
    configured_url = ENV["GOPROTEXT_API_URL"].presence
    return configured_url.delete_suffix("/") if configured_url

    ENV.fetch("GOPROTEXT_LOANS_URL", "https://id.goprotext.com/api/v2/loans")
      .sub(%r{/loans/?\z}, "")
  end

  def goprotext_token_url
    ENV.fetch("GOPROTEXT_OAUTH_TOKEN_URL", "https://id.goprotext.com/oauth/token")
  end

  def goprotext_token_grant_type
    ENV.fetch("GOPROTEXT_OAUTH_TOKEN_GRANT_TYPE", "refresh_token")
  end

  def goprotext_company_id
    company.protext_id.to_s.presence || ENV["GOPROTEXT_COMPANY_ID"].to_s.presence
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
end

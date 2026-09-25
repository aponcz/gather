require "uri"

class FrontendOrigin
  def self.allowed?(origin)
    uri = URI.parse(origin.to_s)
    return false unless %w[http https].include?(uri.scheme) && uri.host.present?
    return false if uri.userinfo || uri.query || uri.fragment || uri.path.present?

    base = ENV["FRONTEND_BASE_DOMAIN"].to_s.downcase
    if base.present? && uri.scheme == "https" && uri.port == 443
      return true if uri.host == base || uri.host.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\.#{Regexp.escape(base)}\z/)
    end

    if !Rails.env.production? && uri.port == 5173
      return true if uri.host == "localhost" || uri.host.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\.localhost\z/)
    end

    # Explicit origins retain support for a custom frontend hostname.
    ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject { |value| value == "*" }.include?(origin)
  rescue URI::InvalidURIError
    false
  end

  def self.company_subdomain(origin)
    host = URI.parse(origin).host
    base = ENV["FRONTEND_BASE_DOMAIN"].presence || ("localhost" unless Rails.env.production?)
    return nil unless base && host.end_with?(".#{base}")

    subdomain = host.delete_suffix(".#{base}")
    # The app hostname is the shared entry point, not a tenant.
    subdomain unless subdomain == "app"
  end
end

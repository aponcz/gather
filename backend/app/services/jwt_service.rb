class JwtService
  ALGORITHM = "HS256"

  def self.encode(payload, expires_in: 12.hours)
    exp = expires_in.from_now.to_i
    JWT.encode(payload.merge(exp: exp), secret, ALGORITHM)
  end

  def self.decode(token)
    JWT.decode(token, secret, true, algorithm: ALGORITHM).first
  end

  def self.secret
    ENV.fetch("JWT_SECRET", "development-jwt-secret-change-me")
  end
end

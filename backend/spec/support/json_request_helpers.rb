module JsonRequestHelpers
  def json_headers(extra_headers = {})
    { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }.merge(extra_headers)
  end

  def json_body
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include JsonRequestHelpers, type: :request
end

class StorageService
  def initialize
    @bucket = ENV.fetch("S3_BUCKET", "fileinvite")
    @client = Aws::S3::Client.new(
      region: ENV.fetch("AWS_REGION", "us-east-1"),
      endpoint: ENV["S3_ENDPOINT"],
      force_path_style: ENV.fetch("S3_FORCE_PATH_STYLE", "true") == "true",
      access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID", "minioadmin"),
      secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY", "minioadmin")
    )
    @resource = Aws::S3::Resource.new(client: @client)
  end

  def presigned_upload_url(key:, content_type:, expires_in: 15.minutes.to_i)
    object = @resource.bucket(@bucket).object(key)
    object.presigned_url(:put, expires_in: expires_in, content_type: content_type)
  end

  def presigned_download_url(key:, expires_in: 15.minutes.to_i)
    object = @resource.bucket(@bucket).object(key)
    object.presigned_url(:get, expires_in: expires_in)
  end
end

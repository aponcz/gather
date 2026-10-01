require 'rails_helper'

RSpec.describe StorageService do
  describe '#presigned_upload_url' do
    it 'does not sign the browser-controlled content type header' do
      client = instance_double(Aws::S3::Client)
      resource = instance_double(Aws::S3::Resource)
      bucket = instance_double(Aws::S3::Bucket)
      object = instance_double(Aws::S3::Object)
      allow(Aws::S3::Client).to receive(:new).and_return(client)
      allow(Aws::S3::Resource).to receive(:new).with(client: client).and_return(resource)
      allow(resource).to receive(:bucket).with('gather').and_return(bucket)
      allow(bucket).to receive(:object).with('uploads/document.pdf').and_return(object)

      expect(object).to receive(:presigned_url)
        .with(:put, expires_in: 900)
        .and_return('https://gather.s3.amazonaws.com/uploads/document.pdf')

      url = described_class.new.presigned_upload_url(key: 'uploads/document.pdf')

      expect(url).to eq('https://gather.s3.amazonaws.com/uploads/document.pdf')
    end
  end

  describe 'production S3 configuration' do
    it 'uses the AWS SDK credential chain and standard S3 endpoint' do
      production = ActiveSupport::EnvironmentInquirer.new('production')
      client = instance_double(Aws::S3::Client)
      resource = instance_double(Aws::S3::Resource)
      allow(Rails).to receive(:env).and_return(production)
      allow(Aws::S3::Resource).to receive(:new).with(client: client).and_return(resource)

      expect(Aws::S3::Client).to receive(:new)
        .with(region: ENV.fetch('AWS_REGION', 'us-east-1'))
        .once
        .and_return(client)

      service = described_class.new

      expect(service.send(:download_client)).to be(client)
    end
  end
end

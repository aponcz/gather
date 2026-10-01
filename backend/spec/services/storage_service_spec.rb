require 'rails_helper'

RSpec.describe StorageService do
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

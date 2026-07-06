require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'goprotext refresh token persistence' do
    it 'has goprotext_refresh_token column' do
      expect(described_class.column_names).to include('goprotext_refresh_token')
    end

    it 'persists goprotext_refresh_token value' do
      company = Company.create!(name: "OAuth Company #{SecureRandom.hex(4)}")
      user = User.create!(
        company: company,
        name: 'OAuth User',
        email: "oauth-user-#{SecureRandom.hex(4)}@example.test",
        password: 'password123',
        role: 'customer',
        goprotext_refresh_token: 'refresh-token-123'
      )

      expect(user.reload.goprotext_refresh_token).to eq('refresh-token-123')
    end
  end
end

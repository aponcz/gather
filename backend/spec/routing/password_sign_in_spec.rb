require 'rails_helper'

RSpec.describe 'Password sign-in routes', type: :routing do
  it 'does not expose the legacy password login endpoint' do
    expect(post: '/api/v1/auth/login').not_to be_routable
  end

  it 'does not expose the Devise password sign-in endpoint' do
    expect(post: '/api/v1/auth/sign_in').not_to be_routable
  end
end

require 'rails_helper'

RSpec.describe AppConfig do
  describe '.frontend_url' do
    it 'prefers the FRONTEND_URL env var' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('FRONTEND_URL', any_args).and_return('https://env.example.com')

      expect(described_class.frontend_url).to eq('https://env.example.com')
    end

    it 'falls back to encrypted credentials when the env var is unset' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('FRONTEND_URL', any_args) { |_key, &blk| blk.call }
      allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return('https://creds.example.com')

      expect(described_class.frontend_url).to eq('https://creds.example.com')
    end

    it 'falls back to the local web dev server in development when nothing else is set' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('FRONTEND_URL', any_args) { |_key, &blk| blk.call }
      allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return(nil)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

      expect(described_class.frontend_url).to eq('http://localhost:3001')
    end
  end
end

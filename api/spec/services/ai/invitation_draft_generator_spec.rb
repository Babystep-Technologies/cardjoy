# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ai::InvitationDraftGenerator do
  let(:user) { create(:user) }

  describe '#generate' do
    subject(:result) { generator.generate }

    let(:generator) { described_class.new(user: user, prompt: prompt, options: options) }
    let(:prompt) { 'Join us for a celebration!' }
    let(:options) { {} }

    it 'returns a hash with required keys' do
      expected_keys = [ :preview_title, :preview_message, :preview_event_date, :preview_event_time, :preview_location, :ai_payload ]
      expect(result.keys).to contain_exactly(*expected_keys)
    end

    describe 'preview fields' do
      it 'generates preview_title from occasion or default text' do
        expect(result[:preview_title]).to include('invited to')
        expect(result[:preview_title]).to include('special event')
      end

      it 'generates preview_title with occasion when provided' do
        generator = described_class.new(user: user, prompt: prompt, options: { occasion: 'wedding' })
        expect(generator.generate[:preview_title]).to include('wedding')
      end

      it 'generates preview_message from prompt' do
        expect(result[:preview_message]).to include('Hey!')
        expect(result[:preview_message]).to include(prompt)
      end

      it 'truncates long prompts in preview_message' do
        long_prompt = 'a' * 300
        generator = described_class.new(user: user, prompt: long_prompt, options: {})
        message = generator.generate[:preview_message]
        # "Hey! We'd love for you to join us. " (36 chars) + 200 char truncation = 236 chars
        expect(message.length).to be <= 240
      end

      it 'handles nil prompt gracefully' do
        generator = described_class.new(user: user, prompt: nil, options: {})
        expect(generator.generate[:preview_message]).to include('Hey!')
      end

      it 'uses provided event_date or defaults to tomorrow' do
        expect(result[:preview_event_date]).to eq(Date.tomorrow.to_s)
      end

      it 'uses event_date from options when provided' do
        custom_date = '2026-01-15'
        generator = described_class.new(user: user, prompt: prompt, options: { event_date: custom_date })
        expect(generator.generate[:preview_event_date]).to eq(custom_date)
      end

      it 'uses provided event_time or defaults to 18:00' do
        expect(result[:preview_event_time]).to eq('18:00')
      end

      it 'uses event_time from options when provided' do
        generator = described_class.new(user: user, prompt: prompt, options: { event_time: '19:30' })
        expect(generator.generate[:preview_event_time]).to eq('19:30')
      end

      it 'uses provided location or defaults to TBD' do
        expect(result[:preview_location]).to eq('TBD')
      end

      it 'uses location from options when provided' do
        generator = described_class.new(user: user, prompt: prompt, options: { location: 'Central Park' })
        expect(generator.generate[:preview_location]).to eq('Central Park')
      end
    end

    describe 'ai_payload' do
      it 'includes generated_at timestamp' do
        before = Time.current
        payload = result[:ai_payload]
        after = Time.current

        generated_at = Time.iso8601(payload[:generated_at])
        # Allow 2 seconds tolerance for test execution time
        expect(generated_at).to be_within(2.seconds).of(before)
      end

      it 'includes the original prompt' do
        expect(result[:ai_payload][:prompt]).to eq(prompt)
      end

      it 'includes model identifier from options or default' do
        expect(result[:ai_payload][:model]).to eq('stub-v1')
      end

      it 'uses custom model from options when provided' do
        generator = described_class.new(user: user, prompt: prompt, options: { model: 'gpt-4' })
        expect(generator.generate[:ai_payload][:model]).to eq('gpt-4')
      end

      it 'includes content hash with all preview fields' do
        content = result[:ai_payload][:content]
        expect(content).to include(:title, :message, :event_date, :event_time, :location)
      end

      it 'content mirrors preview fields' do
        content = result[:ai_payload][:content]
        expect(content[:title]).to eq(result[:preview_title])
        expect(content[:message]).to eq(result[:preview_message])
        expect(content[:event_date]).to eq(result[:preview_event_date])
        expect(content[:event_time]).to eq(result[:preview_event_time])
        expect(content[:location]).to eq(result[:preview_location])
      end
    end

    describe 'idempotency' do
      it 'generates consistent results for same inputs' do
        generator1 = described_class.new(user: user, prompt: prompt, options: { occasion: 'birthday' })
        generator2 = described_class.new(user: user, prompt: prompt, options: { occasion: 'birthday' })

        result1 = generator1.generate
        result2 = generator2.generate

        # Preview fields should match (timestamps may differ slightly)
        expect(result1[:preview_title]).to eq(result2[:preview_title])
        expect(result1[:preview_message]).to eq(result2[:preview_message])
        expect(result1[:preview_location]).to eq(result2[:preview_location])
      end
    end

    describe 'edge cases' do
      it 'handles empty prompt string' do
        generator = described_class.new(user: user, prompt: '', options: {})
        result = generator.generate
        expect(result[:preview_message]).to include('Hey!')
      end

      it 'handles empty options hash' do
        generator = described_class.new(user: user, prompt: prompt, options: {})
        result = generator.generate
        expect(result[:preview_title]).to include('special event')
        expect(result[:preview_event_time]).to eq('18:00')
        expect(result[:preview_location]).to eq('TBD')
      end

      it 'handles all options provided' do
        options = {
          occasion: 'conference',
          event_date: '2026-06-15',
          event_time: '09:00',
          location: 'San Francisco Convention Center',
          model: 'claude-3'
        }
        generator = described_class.new(user: user, prompt: prompt, options: options)
        result = generator.generate

        expect(result[:preview_title]).to include('conference')
        expect(result[:preview_event_date]).to eq('2026-06-15')
        expect(result[:preview_event_time]).to eq('09:00')
        expect(result[:preview_location]).to eq('San Francisco Convention Center')
        expect(result[:ai_payload][:model]).to eq('claude-3')
      end
    end
  end
end

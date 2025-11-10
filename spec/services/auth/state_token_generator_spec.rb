require 'rails_helper'

RSpec.describe Auth::StateTokenGenerator, type: :service do
  let(:request) { instance_double(ActionDispatch::Request, user_agent: 'Mozilla/5.0', ip: '192.168.1.1') }
  let(:provider) { :GOOGLE }
  let(:redis_service) { instance_double(RedisService) }
  let(:encryptor) { instance_double(EncryptorService) }
  let(:encrypted_token) { 'encrypted_state_token_abc123' }

  subject(:service) { described_class.new(request: request, provider: provider, encryptor: encryptor) }

  before do
    allow(request).to receive(:is_a?).and_return(true)
    allow(RedisService).to receive(:instance).and_return(redis_service)
    allow(redis_service).to receive(:set).and_return(true)
    allow(encryptor).to receive(:encrypt).and_return(encrypted_token)
  end

  describe '#call' do
    context 'when token generation is successful' do
      it 'generates a state_token successfully' do
        service = described_class.new(request: request, provider: provider, encryptor: encryptor)
        service.call

        expect(service.valid?).to be_truthy
        expect(service.errors).to be_nil
        expect(service.state_token).to eq(encrypted_token)
      end

      it 'persists data in Redis' do
        expect(redis_service).to receive(:set).with(
          anything,
          anything,
          ex: anything
        )

        service = described_class.new(request: request, provider: provider, encryptor: encryptor)
        service.call
      end

      it 'encrypts the Redis key' do
        expect(encryptor).to receive(:encrypt).with(anything).and_return(encrypted_token)

        service = described_class.new(request: request, provider: provider, encryptor: encryptor)
        service.call
      end

      it 'generates a token with the correct format' do
        service = described_class.new(request: request, provider: provider, encryptor: encryptor)
        service.call

        expect(service.state_token).not_to be_nil
        expect(service.state_token).to be_a(String)
      end
    end

    context 'when an error occurs' do
      context 'with invalid request' do
        before do
          allow(request).to receive(:is_a?).and_return(false)
        end

        it 'marks the service as invalid' do
          service = described_class.new(request: request, provider: provider, encryptor: encryptor)
          service.call

          expect(service.valid?).to be_falsey
          expect(service.errors[:code]).to eq(Auth::ErrorCodes::INVALID_REQUEST_TYPE)
          expect(service.state_token).to be_nil
        end
      end

      context 'with invalid provider' do
        let(:provider) { :FACEBOOK }

        it 'marks the service as invalid' do
          service.call

          expect(service).not_to be_valid
          expect(service.errors[:code]).to eq(Auth::ErrorCodes::INVALID_PROVIDER)
          expect(service.state_token).to be_nil
        end
      end

      context 'when encryption fails' do
        before do
          allow(encryptor).to receive(:encrypt)
            .and_raise(ActiveSupport::MessageEncryptor::InvalidMessage.new('Encryption failed'))
        end

        it 'marks the service as invalid and logs the error' do
          service.call

          expect(service).not_to be_valid
          expect(service.errors[:code]).to eq(Auth::ErrorCodes::INVALID_ENCRYPTED_PAYLOAD)
          expect(service.state_token).to be_nil
        end
      end

      context 'when Redis fails' do
        before do
          allow(redis_service).to receive(:set).and_raise(Redis::CannotConnectError.new('Connection failed'))
        end

        it 'marks the service as invalid and logs the error' do
          service.call

          expect(service).not_to be_valid
          expect(service.errors[:code]).to eq(Errors::GlobalCodes::REDIS_CONNECTION_ERROR)
          expect(service.state_token).to be_nil
        end
      end
    end
  end

  describe 'private data construction' do
    describe '#build_data_from_request' do
      let(:user_agent) { 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
      let(:ip_address) { '203.0.113.42' }
      let(:request) { instance_double(ActionDispatch::Request, user_agent: user_agent, ip: ip_address) }

      it 'builds the data hash correctly' do
        service = described_class.new(request: request, provider: provider, encryptor: encryptor)
        service.call

        # Verify that Redis received the correct data
        expect(redis_service).to have_received(:set) do |_key, data_json, _options|
          data = JSON.parse(data_json)
          expect(data['user_agent']).to eq(user_agent)
          expect(data['ip_address']).to eq(ip_address)
        end
      end

      it 'includes the user_agent from the request' do
        service.call

        expect(redis_service).to have_received(:set) do |_key, data_json, _options|
          data = JSON.parse(data_json)
          expect(data['user_agent']).to eq(user_agent)
        end
      end

      it 'includes the IP from the request' do
        service.call

        expect(redis_service).to have_received(:set) do |_key, data_json, _options|
          data = JSON.parse(data_json)
          expect(data['ip_address']).to eq(ip_address)
        end
      end
    end

    describe '#build_key_name' do
      it 'generates a key with the correct format' do
        service.call

        expect(redis_service).to have_received(:set) do |key, _data, _options|
          expect(key).to match(/^STATE_TOKEN:GOOGLE:\d+:[a-f0-9]{32}$/)
        end
      end

      it 'includes the provider in the key' do
        service.call

        expect(redis_service).to have_received(:set) do |key, _data, _options|
          expect(key).to include('GOOGLE')
        end
      end

      it 'includes a timestamp in the key' do
        service.call

        expect(redis_service).to have_received(:set) do |key, _data, _options|
          timestamp = key.split(':')[2].to_i
          expect(timestamp).to be_within(5).of(Time.now.to_i)
        end
      end

      it 'includes a unique random identifier' do
        service.call

        expect(redis_service).to have_received(:set) do |key, _data, _options|
          random_part = key.split(':')[3]
          expect(random_part).to match(/^[a-f0-9]{32}$/)
        end
      end

      it 'generates unique keys on successive calls' do
        keys = []

        allow(redis_service).to receive(:set) do |key, _data, _options|
          keys << key
        end

        3.times do
          service = described_class.new(request: request, provider: provider, encryptor: encryptor)
          service.call
        end

        expect(keys.uniq.length).to eq(3)
      end
    end

    describe '#persist_data_in_redis' do
      it 'persists data in Redis with expiration time' do
        expected_expiration = ENV['STATE_TOKEN_EXPIRATION_TIME'].to_i.minutes

        service.call

        expect(redis_service).to have_received(:set).with(
          anything,
          anything,
          ex: expected_expiration
        )
      end

      it 'serializes data as JSON' do
        service.call

        expect(redis_service).to have_received(:set) do |_key, data_json, _options|
          expect { JSON.parse(data_json) }.not_to raise_error
        end
      end
    end

    describe '#encrypt_data' do
      let(:redis_key) { 'STATE_TOKEN:GOOGLE:1234567890:abc123' }

      it 'encrypts the Redis key' do
        service.call

        expect(encryptor).to have_received(:encrypt)
      end

      it 'assigns the encrypted token to state_token' do
        service.call

        expect(service.state_token).to eq(encrypted_token)
      end

      context 'when a signature verification error occurs' do
        before do
          allow(encryptor).to receive(:encrypt)
            .and_raise(ActiveSupport::MessageVerifier::InvalidSignature.new('Invalid signature'))
        end

        it 'catches the error and re-raises it with a custom message' do
          service.call

          expect(service).not_to be_valid
          expect(service.errors[:code]).to eq(Auth::ErrorCodes::INVALID_ENCRYPTED_PAYLOAD)
        end
      end

      context 'when an invalid encrypted message error occurs' do
        before do
          allow(encryptor).to receive(:encrypt)
            .and_raise(ActiveSupport::MessageEncryptor::InvalidMessage.new('Invalid message'))
        end

        it 'catches the error and re-raises it with a custom message' do
          service.call

          expect(service).not_to be_valid
          expect(service.errors[:code]).to eq(Auth::ErrorCodes::INVALID_ENCRYPTED_PAYLOAD)
        end
      end
    end
  end

  describe 'complete flow integration' do
    it 'executes the complete flow correctly' do
      service.call

      expect(service).to be_valid
      expect(service.state_token).to eq(encrypted_token)
      expect(service.errors).to be_nil
    end

    it 'maintains the correct order of operations' do
      call_order = []

      allow(redis_service).to receive(:set) do |*args|
        call_order << :redis_set
      end

      allow(encryptor).to receive(:encrypt) do |*args|
        call_order << :encrypt
        encrypted_token
      end

      service.call

      expect(call_order).to eq([ :redis_set, :encrypt ])
    end
  end

  describe 'read attributes' do
    it 'allows reading the state_token' do
      expect(service).to respond_to(:state_token)
    end

    it 'allows checking if the service is valid' do
      expect(service).to respond_to(:valid?)
    end

    it 'allows reading the errors' do
      expect(service).to respond_to(:errors)
    end
  end
end

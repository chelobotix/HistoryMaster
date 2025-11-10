require 'rails_helper'

RSpec.describe Auth::GoogleAuthGenerator, type: :service do
  let(:request) { instance_double(ActionDispatch::Request, user_agent: 'Mozilla/5.0', ip: '192.168.1.1') }
  let(:state_token_service_class) { class_double(Auth::StateTokenGenerator) }
  let(:state_token_service_instance) { instance_double(Auth::StateTokenGenerator) }
  let(:state_token) { 'encrypted_state_token_abc123' }

  before do
    allow(state_token_service_class).to receive(:new).and_return(state_token_service_instance)
    allow(state_token_service_instance).to receive(:call)
    allow(state_token_service_instance).to receive(:valid?).and_return(true)
    allow(state_token_service_instance).to receive(:state_token).and_return(state_token)
  end

  describe '#call' do
    context 'when URL generation is successful' do
      it 'generates a URL successfully' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.valid?).to be_truthy
        expect(service.errors).to be_nil
        expect(service.url).not_to be_nil
      end

      it 'generates a state token using the state token service' do
        expect(state_token_service_class).to receive(:new).with(request: request, provider: :GOOGLE)
        expect(state_token_service_instance).to receive(:call)

        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call
      end

      it 'generates a URL with the correct format' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.url).to be_a(String)
        expect(service.url).to include(ENV["BASE_URL"])
        expect(service.url).to include("state=#{state_token}")
        expect(service.url).to include("client_id=#{ENV["GOOGLE_CLIENT_ID"]}")
        expect(service.url).to include("redirect_uri=#{ENV["GOOGLE_REDIRECT_URL"]}")
      end

      it 'constructs the URL with proper parameter separation' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        uri = URI.parse(service.url)
        params = URI.decode_www_form(uri.query).to_h

        expect(params['state']).to eq(state_token)
        expect(params['client_id']).to eq(ENV["GOOGLE_CLIENT_ID"])
        expect(params['redirect_uri']).to eq(ENV["GOOGLE_REDIRECT_URL"])
      end
    end

    context 'when an error occurs' do
      context 'with state token generation failure' do
        let(:service_error) { "code: #{Errors::GlobalCodes::UNEXPECTED_ERROR}: Failed to generate state token" }

        before do
          allow(state_token_service_instance).to receive(:valid?).and_return(false)
          allow(state_token_service_instance).to receive(:errors).and_return(service_error)
        end

        it 'marks the service as invalid' do
          service = described_class.new(request: request, state_token_service: state_token_service_class)
          service.call

          expect(service.valid?).to be_falsey
          expect(service.url).to be_nil
          expect(service.errors).to include("code: #{Errors::GlobalCodes::UNEXPECTED_ERROR}")
        end
      end
    end
  end

  describe 'private URL construction' do
    describe '#generate_state_token' do
      it 'instantiates the state token service with correct parameters' do
        expect(state_token_service_class).to receive(:new).with(
          request: request,
          provider: :GOOGLE
        ).and_return(state_token_service_instance)

        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call
      end

      it 'calls the state token service' do
        expect(state_token_service_instance).to receive(:call)

        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call
      end

      it 'retrieves the state token from the service' do
        expect(state_token_service_instance).to receive(:state_token).and_return(state_token)

        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.url).to include("state=#{state_token}")
      end

      context 'when state token service is invalid' do
        let(:error_code) { 'INVALID_REQUEST' }
        let(:error_message) { 'Invalid request type' }
        let(:service_error) { "code: #{error_code}: #{error_message}" }

        before do
          allow(state_token_service_instance).to receive(:valid?).and_return(false)
          allow(state_token_service_instance).to receive(:errors).and_return(service_error)
        end

        it 'raises the error from the state token service' do
          service = described_class.new(request: request, state_token_service: state_token_service_class)
          service.call

          expect(service).not_to be_valid
          expect(service.errors).to include("code: #{error_code}")
        end
      end
    end

    describe '#generate_url' do
      it 'builds the URL with the base URL' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.url).to start_with(ENV["BASE_URL"])
      end

      it 'includes the state token in the URL' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.url).to include("state=#{state_token}")
      end

      it 'includes the client ID in the URL' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.url).to include("client_id=#{ENV["GOOGLE_CLIENT_ID"]}")
      end

      it 'includes the redirect URI in the URL' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.url).to include("redirect_uri=#{ENV["GOOGLE_REDIRECT_URL"]}")
      end

      it 'includes the response type in the URL' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.url).to include('response_type=code')
      end

      it 'includes the scopes in the URL' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(service.url).to include('scope=email profile')
      end
    end

    describe '#generate_google_auth_url' do
      it 'coordinates state token generation and URL building' do
        service = described_class.new(request: request, state_token_service: state_token_service_class)
        service.call

        expect(state_token_service_instance).to have_received(:call)
        expect(service.url).not_to be_nil
      end
    end
  end

  describe 'complete flow integration' do
    it 'executes the complete flow correctly' do
      service = described_class.new(request: request, state_token_service: state_token_service_class)
      service.call

      expect(service).to be_valid
      expect(service.url).to eq("#{ENV["BASE_URL"]}?state=#{state_token}&client_id=#{ENV["GOOGLE_CLIENT_ID"]}&redirect_uri=#{ENV["GOOGLE_REDIRECT_URL"]}&response_type=code&scope=email profile")
      expect(service.errors).to be_nil
    end
    it 'generates different URLs when called multiple times with different tokens' do
      urls = []

      3.times do |i|
        token = "encrypted_token_#{i}"
        allow(state_token_service_instance).to receive(:state_token).and_return(token)

        service_instance = described_class.new(request: request, state_token_service: state_token_service_class)
        service_instance.call
        urls << service_instance.url
      end

      expect(urls.uniq.length).to eq(3)
    end
  end
end

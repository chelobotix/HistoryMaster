module Auth
  module Google
    class UserPayloadProcessor
      include BaseService

      private attr_reader :google_payload
      attr_reader :auth_headers

      def initialize(google_payload:)
        @google_payload = google_payload
        @auth_headers = nil
      end

      def call
        process_google_payload
        set_as_valid!

      rescue StandardError => e
        set_as_invalid!
        set_errors(e.message)
      end

      private

      def process_google_payload
        ActiveRecord::Base.transaction do
          user = find_or_create_user
          @auth_headers = generate_devise_token(user)
        end
      end

      def find_or_create_user
        user = User.find_by(email: google_payload[:email])

        user.presence || handle_user_creation
      end

      def handle_user_creation
        user = User.new(
          email: google_payload[:email],
          provider: :google,
          uid: google_payload[:email],
          password: Devise.friendly_token[0, 20],
          confirmed_at: Time.current
        )

        user.skip_confirmation_notification!
        user.save!

        user
      end

      def generate_devise_token(user)
        client_id = SecureRandom.urlsafe_base64(nil, false)
        token = SecureRandom.urlsafe_base64(nil, false)

        token_hash = BCrypt::Password.create(token)
        expiry = (Time.now + DeviseTokenAuth.token_lifespan).to_i

        user.tokens[client_id] = {
          token: token_hash,
          expiry: expiry
        }

        user.save!

        auth_data = {
          "access-token": token,
          "token-type": "Bearer",
          "client": client_id,
          "expiry": expiry.to_s,
          "uid": user.uid
        }

        encoded_auth = Base64.strict_encode64(auth_data.to_json)

        auth_data.merge({
          "authorization": "Bearer #{encoded_auth}"
        })
      end
    end
  end
end

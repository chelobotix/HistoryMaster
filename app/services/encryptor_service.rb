require "active_support/message_encryptor"

class EncryptorService
  include Singleton

  STATE_TOKEN_SECRET = ENV["STATE_TOKEN_SECRET"].freeze
  private_constant :STATE_TOKEN_SECRET

  private attr_reader :encryptor

  def initialize
    key = ActiveSupport::KeyGenerator.new(STATE_TOKEN_SECRET).generate_key("token_salt", 32)
    @encryptor = ActiveSupport::MessageEncryptor.new(key)
  end

  def encrypt(payload)
    encrypted_payload = encryptor.encrypt_and_sign(payload)
    Base64.urlsafe_encode64(encrypted_payload)
  end

  def decrypt(encrypted_payload)
    decrypted_payload = Base64.urlsafe_decode64(encrypted_payload)
    encryptor.decrypt_and_verify(decrypted_payload)
  end
end

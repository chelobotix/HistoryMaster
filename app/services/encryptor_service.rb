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
    encryptor.encrypt_and_sign(payload)
  end

  def decrypt(encrypted_payload)
    encryptor.decrypt_and_verify(encrypted_payload)
  end
end

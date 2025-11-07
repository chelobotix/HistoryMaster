require "active_support/message_encryptor"

Rails.application.config.after_initialize do
  begin
    EncryptorService.instance
  rescue => e
    Rails.logger.error "Encryptor service initialization failed: #{e.message}"
    raise e
  end
end

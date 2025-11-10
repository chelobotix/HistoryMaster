module Errors
  class Custom < StandardError
    attr_reader :code, :message

    def initialize(code:, message:)
      @code = code
      @message = message
      super(message)
    end
  end
end

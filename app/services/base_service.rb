module BaseService
  attr_reader :errors, :valid

  def valid?
    @valid
  end

  private

  def set_as_invalid!
    @valid = false
  end

  def set_as_valid!
    @valid = true
  end

  def set_errors(code, message)
    Rails.logger.error("⛔ >>>>>-----> #{self.class.name}: code: #{code}, error: #{message}\n") unless Rails.env.test?
    @errors = { reference: self.class.name, code: code, message: message }
  end
end

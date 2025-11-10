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

  def set_errors(error = "An unexpected error occurred")
    Rails.logger.error("⛔ >>>>>-----> #{self.class.name}: error: #{error}\n") unless Rails.env.test?
    @errors = error
  end
end

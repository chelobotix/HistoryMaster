class TestoController < ApplicationController
  def test
    binding.break
    puts ENV['JWT_SECRET_KEY']

    render json: { message: "test" }
  end
end

class Api::V1::TestoController < ApplicationController
  skip_before_action :authenticate_user!

  def test
    puts ENV["JWT_SECRET_KEY"]

    render json: { message: "test" }
  end
end

class Api::V1::TestoController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :confirm ]

  def test
    puts ENV["JWT_SECRET_KEY"]
    puts ENV["JWT_SECRET_KEY"]

    render json: { message: "test" }
  end

  def confirm
    render json: { message: "confirm" }
  end
end

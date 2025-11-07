class Api::V1::TestoController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :confirm ]

  def test
    RedisService.instance.set("test", "test")
    puts ENV["JWT_SECRET_KEY"]

    render json: { message: "test" }
  end

  def confirm
    RedisService.instance.set("test", "test")
    render json: { message: "confirm" }
  end
end

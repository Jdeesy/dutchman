require 'bunny'

class WelcomeController < ApplicationController
  def index
    # this is the home page where everything is displayed to the user
    # this conn/bunny stuff is what is talking with the RabbitMQ Client
    # we create a new channel, and then declare a queue called buffet

    conn = Bunny.new
    conn.start
    channel = conn.create_channel
    buffetq = channel.queue('buffet')

    @shrimp_in_buffet = buffetq.message_count
    @shrimp_in_stock_room = ShrimpDelivery.sum(:num_shrimp)
    @delivery_person_status = 'Idle'
  end

  def restock_refill
    conn = Bunny.new
    conn.start
    channel = conn.create_channel
    exchange = channel.default_exchange

    if params[:restock]
      num = params[:num_shrimp].to_i
      exchange.publish({num: num}.to_json, routing_key: 'shrimp-deliveries')
    elsif params[:refill]
      shrimp_in_stock_room = 0
      ActiveRecord::Base.transaction do
        shrimp_in_stock_room = ShrimpDelivery.sum(:num_shrimp)
        ShrimpDelivery.delete_all
      end

      shrimp_in_stock_room.times do
        exchange.publish('shrimp', routing_key: 'buffet')
      end
    end

    redirect_to(action: :index)
  end
end

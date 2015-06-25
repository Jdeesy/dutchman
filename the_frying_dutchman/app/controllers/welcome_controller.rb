require 'bunny'

class WelcomeController < ApplicationController
  def index
    # this is the home page where everything is displayed to the user

    conn = Bunny.new
    conn.start
    channel = conn.create_channel
    buffetq = channel.queue('buffet')
    # this conn/bunny stuff is what is talking with the RabbitMQ Client
    # we create a new channel, and then declare a queue called buffet

    @shrimp_in_buffet = buffetq.message_count
    # from what I understand, this looks at the queue buffet that is on the RabbitMQ channel
    # counts the number of messages and sets it to a variable
    @shrimp_in_stock_room = ShrimpDelivery.sum(:num_shrimp)
    # sums up the number of shrimp (in the database), and sets it to a variable
    @delivery_person_status = 'Idle'
    # sets the delivery_person status to idle
  end

  def restock_refill
    # this is what I would consider a post page. Basically we send info here and redirect back to the index page

    conn = Bunny.new
    conn.start
    channel = conn.create_channel
    exchange = channel.default_exchange
    # same as the index page but sets up the exchange
    # from what I read an exchange takes messages from the application and routes it to a queue

    if params[:restock]
      num = params[:num_shrimp].to_i
      exchange.publish({num: num}.to_json, routing_key: 'shrimp-deliveries')
      # if we restock, it gets the number of shrimp from the params
      # then it publish a message to the queue with the json object of the number of shrimp to the routing key queue
      # need to find where shrimp deliveries queue is defined
    elsif params[:refill]
      shrimp_in_stock_room = 0
      ActiveRecord::Base.transaction do
        shrimp_in_stock_room = ShrimpDelivery.sum(:num_shrimp)
        ShrimpDelivery.delete_all
      end
      # if we refill, it first sets the shrimp in stock to 0
      # then if can set the the total of shrimp from the database and delete all the shirmpdeliveries it will (needs to do both because of transaction)

      shrimp_in_stock_room.times do
        exchange.publish('shrimp', routing_key: 'buffet')
      end
      # publish a message to the buffet queue for each shrimp in the shrimp in stock
    end

    redirect_to(action: :index)
  end
end

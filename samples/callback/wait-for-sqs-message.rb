#!/usr/bin/ruby

require "aws-sdk-sqs"

queue_url = ARGV[0]
sqs = Aws::SQS::Client.new

loop do
  response = sqs.receive_message(
    queue_url: queue_url,
    max_number_of_messages: 1,
    wait_time_seconds: 20,
  )

  if response.messages.any?
    message = response.messages.first

    puts message.body

    sqs.delete_message(
      queue_url: queue_url,
      receipt_handle: message.receipt_handle,
    )

    break
  else
    sleep 5
  end
end

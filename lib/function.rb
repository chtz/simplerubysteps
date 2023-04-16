require "simplerubysteps"

if ENV["QUEUE"]
  require "aws-sdk-sqs"
  require "json"

  class QueueClient
    def initialize(sqs_client, queue)
      @sqs_client = sqs_client
      @queue = queue
    end

    def send(data)
      @sqs_client.send_message(queue_url: @queue, message_body: data.to_json)
    end
  end

  $queue_client = QueueClient.new(Aws::SQS::Client.new, ENV["QUEUE"])
else
  $queue_client = nil
end

require "./workflow.rb"

include Simplerubysteps

def handler(event:, context:)
  puts ENV.inspect if ENV["DEBUG"]
  puts event if ENV["DEBUG"]
  puts context.inspect if ENV["DEBUG"]

  if event["Token"]
    unless $queue_client
      $sm.states[ENV["task"].to_sym].perform_action event["Input"], event["Token"]
    else
      $sm.states[ENV["task"].to_sym].perform_queue_action event["Input"], event["Token"], $queue_client
    end
  else
    $sm.states[ENV["task"].to_sym].perform_action event["Input"]
  end
end

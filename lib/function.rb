require 'json'
require './workflow.rb'

def handler(event:, context:)
  puts ENV.inspect
  puts event
  puts context.inspect
  $sm.states[event["Task"].to_sym].perform_action event["Input"]
end

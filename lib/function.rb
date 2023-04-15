require "simplerubysteps"

require "./workflow.rb"

include Simplerubysteps

def handler(event:, context:)
  puts ENV.inspect if ENV["DEBUG"]
  puts event if ENV["DEBUG"]
  puts context.inspect if ENV["DEBUG"]

  if event["Token"]
    $sm.states[event["Task"].to_sym].perform_action event["Input"], event["Token"]
  else
    $sm.states[event["Task"].to_sym].perform_action event["Input"]
  end
end

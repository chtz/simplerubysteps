require "json"
require "./workflow.rb"

def handler(event:, context:)
  puts ENV.inspect # FIXME remove DEBUG code
  puts event # FIXME remove DEBUG code
  puts context.inspect # FIXME remove DEBUG code

  if event["Token"]
    $sm.states[event["Task"].to_sym].perform_action event["Input"], event["Token"]
  else
    $sm.states[event["Task"].to_sym].perform_action event["Input"]
  end
end

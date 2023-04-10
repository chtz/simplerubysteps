#!/usr/bin/ruby

require "simplerubysteps"
include Simplerubysteps

task :t1 do
  action do |input|
    puts "Task t1: #{input}"
    input.merge({ "Foo1" => (input["foo"] == "John Wick" ? "ja" : "nein") })
  end

  choice :t2 do
    string_matches "$.Foo1", "ja" do
      callback :t3 do
        action do |input, token|
          puts "Callback t3: #{input}, #{token}" # The logged token is picked up by continue-callbackbranch.sh
        end

        transition :t5
      end
    end

    default do
      task :t4 do
        action do |input|
          puts "Task t4: #{input}"
          input.merge({ "Foo4": "Bar4xy" })
        end
      end
    end
  end
end

task :t5 do
  action do |input|
    puts "Task t5: #{input}"
    input.merge({ "Foo5" => "Bar5" })
  end
end

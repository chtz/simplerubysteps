#!/usr/bin/ruby

require "simplerubysteps"
include Simplerubysteps

task :t1 do
  action do |input|
    puts "Task t1: #{input}"
    input.merge({ "t1" => "done", "is_wick" => (input["foo"] == "John Wick" ? "ja" : "nein") })
  end

  choice :t2 do
    string_matches "$.is_wick", "ja" do
      callback :t3 do
        action do |input, token|
          puts "Callback t3: #{input}, callback_token=#{token}" # The logged token is picked up by sample-task-worker.sh
        end

        transition :t5
      end
    end

    default do
      task :t4 do
        action do |input|
          puts "Task t4: #{input}"
          input.merge({ "t4": "done" })
        end
      end
    end
  end
end

task :t5 do
  action do |input|
    puts "Task t5: #{input}"
    input.merge({ "t5" => "done" })
  end
end

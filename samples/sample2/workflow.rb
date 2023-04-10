#!/usr/bin/ruby

require "simplerubysteps"
include Simplerubysteps

task :t1 do
  action do |input|
    puts "Task t1: #{input}"
    input.merge({ "t1" => (input["bar"] ? input["bar"] : "") + "t1" })
  end

  transition_to :t2 do |output|
    output["t1"] == "foot1"
  end

  default_transition_to :t3
end

task :t2 do
  action do |input|
    puts "Task t2: #{input}"
    input.merge({ "t2" => "yes" })
  end

  transition :t4
end

task :t3 do
  action do |input|
    puts "Task t3: #{input}"
    input.merge({ "t3" => "yes" })
  end

  task :t4 do
    action do |input|
      puts "Task t4: #{input}"
      input.merge({ "t4" => "yes" })
    end
  end
end

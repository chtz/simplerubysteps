require "simplerubysteps"
include Simplerubysteps

kind "EXPRESS"

task :start do
  transition_to :even do |data|
    data["number"] % 2 == 0
  end

  default_transition_to :odd
end

task :even do
  action do |data|
    number = data["number"]

    puts "Just for the record, I've discovered an even number: #{number}"

    {
      result: "#{number} is even",
    }
  end
end

task :odd do
  action do |data|
    {
      result: "#{data["number"]} is odd",
    }
  end
end

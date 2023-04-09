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
            task :t3 do
                action do |input|
                    puts "Task t3: #{input}"
                    input.merge({ "Foo3": "Bar3x" })
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

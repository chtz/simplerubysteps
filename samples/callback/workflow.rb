#!/usr/bin/ruby

require "aws-sdk-s3"
require "simplerubysteps"
include Simplerubysteps

sqs_callback :t1 do
  transition :t2
end

task :t2 do
  action do |input|
    puts "t2: #{input}"
    input.merge({ "t2" => "done" })
  end
end

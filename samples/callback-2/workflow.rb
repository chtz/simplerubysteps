#!/usr/bin/ruby

require "aws-sdk-s3"
require "simplerubysteps"
include Simplerubysteps

sqs_callback :t1 do
  transition :expected_t1_called_back
  task_timeout 5, :unexpected_t1_timeout
end

task :unexpected_t1_timeout do
  action do |input|
    input.merge({ "unexpected_t1_timeout" => "yes" })
  end
end

task :expected_t1_called_back do
  transition :t2
  action do |input|
    input.merge({ "expected_t1_called_back" => "yes" })
  end
end

sqs_callback :t2 do
  transition :unxpected_t2_called_back
  task_timeout 5, :expected_t2_timeout
end

task :expected_t2_timeout do
  action do |input|
    input.merge({ "expected_t2_timeout" => "yes" })
  end
end

task :unxpected_t2_called_back do
  action do |input|
    input.merge({ "unxpected_t2_called_back" => "yes" })
  end
end

#!/usr/bin/ruby

require "aws-sdk-s3"
require "simplerubysteps"
include Simplerubysteps

callback :t1 do
  action do |input, token|
    puts "Callback t1: #{input}, callback_token=#{token}" # The logged token is picked up by sample-task-worker.sh
  end

  transition :t2
end

task :t2 do
  iam_permissions <<~JSON
                    {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": ["s3:ListAllMyBuckets"],
                          "Resource": "*"
                        }
                      ]
                    }
                  JSON

  action do |input|
    buckets = nil
    begin
      buckets = Aws::S3::Client.new.list_buckets()[:buckets].map { |b| b[:name] }
    rescue StandardError => error
      buckets = "Error: #{error}"
    end

    puts "Task t2: #{input}"
    input.merge({ "t5" => "done", "buckets" => buckets })
  end
end

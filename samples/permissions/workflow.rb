#!/usr/bin/ruby

require "aws-sdk-s3"
require "simplerubysteps"
include Simplerubysteps

kind "EXPRESS"

task :demo do
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

    input.merge({ "buckets" => buckets })
  end
end

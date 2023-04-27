#!/usr/bin/ruby

require "aws-sdk-s3"
require "simplerubysteps"
include Simplerubysteps

kind "EXPRESS"

task :prep do
  action do |data|
    {
      start: Time.now.to_i,
      failbefore: Time.now.to_i + 20,
    }
  end

  transition :retry
end

task :retry do
  error_retry 1, 10, 1.5
  error_catch :unexpected_error

  action do |data|
    start = data["start"]
    failbefore = data["failbefore"]
    now = Time.now.to_i

    raise "I) Too early #{now - start} <= #{failbefore - start}" unless now > failbefore

    data.merge({
      processed: now,
      failbefore2: Time.now.to_i + 20,
    })
  end

  transition :retry2
end

task :unexpected_error do
  action do |data|
    data.merge({
      unexpected_error: "yes",
    })
  end
end

task :retry2 do
  error_retry 1, 2, 1.5
  error_catch :expected_error

  action do |data|
    start = data["start"]
    failbefore = data["failbefore2"]
    now = Time.now.to_i

    raise "II) Too early #{now - start} <= #{failbefore - start}" unless now > failbefore

    data.merge({
      processed2: now,
    })
  end

  transition :unexpected_success
end

task :expected_error do
  action do |data|
    data.merge({
      expected_error: "yes",
    })
  end
end

task :unexpected_success do
  action do |data|
    data.merge({
      unexpected_success: "yes",
    })
  end
end

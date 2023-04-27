require "simplerubysteps"
include Simplerubysteps

GERMAN_WORDS = ["Hallo"]

def is_german?(word)
  GERMAN_WORDS.include? word
end

wait :wait do
  seconds 1

  transition :delayed_start
end

task :delayed_start do
  transition_to :german do |data|
    is_german? data["hi"]
  end

  default_transition_to :english
end

task :german do
  action do |data|
    { hello_world: "#{data["hi"]} Welt" }
  end
end

task :english do
  action do |data|
    { hello_world: "#{data["hi"]} World" }
  end
end

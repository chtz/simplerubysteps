require "simplerubysteps"
include Simplerubysteps
kind "EXPRESS"

GERMAN_WORDS = ["Hallo"]

def is_german?(word)
  GERMAN_WORDS.include? word
end

task :start do
  transition_to :german do |data|
    is_german? data["hello"]
  end

  default_transition_to :english
end

task :german do
  action do |data|
    { hello_world: "#{data["hello"]} Welt!" }
  end
end

task :english do
  action do |data|
    { hello_world: "#{data["hello"]} World!" }
  end
end

require "simplerubysteps"
include Simplerubysteps

GERMAN_WORDS = ["Hallo"]

def is_german?(word)
  GERMAN_WORDS.include? word
end

parallel :parallel do
  branch do
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
  end

  branch do
    wait :wait2 do
      seconds 1
      transition :foo
    end

    task :foo do
      action do |data|
        {
          :initial => data["hi"],
        }
      end
    end
  end

  transition :consolidate
end

task :consolidate do
  action do |data|
    data[0].merge(data[1])
  end
end

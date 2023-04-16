module Simplerubysteps
  $FUNCTION_ARN = ENV["LAMBDA_FUNCTION_ARN"] ? ENV["LAMBDA_FUNCTION_ARN"] : "unknown"

  def function_name
    return "unknown" unless $FUNCTION_ARN =~ /.+\:function\:(.+)/
    $1
  end

  class StateMachine
    attr_reader :states
    attr_reader :start_at
    attr_accessor :kind

    def initialize()
      @states = {}
      @kind = "STANDARD"
    end

    def add(state)
      @start_at = state.name unless @start_at

      @states[state.name] = state
      state.state_machine = self

      state
    end

    def render
      {
        :StartAt => @start_at,
        :States => @states.map { |name, state| [name, state.render] }.to_h,
      }
    end
  end

  class State
    attr_reader :name
    attr_accessor :state_machine

    def initialize(name)
      @name = name
      @dict = {}
    end

    def []=(key, value)
      @dict[key] = value
    end

    def next=(state)
      @dict[:Next] = (state.is_a? Symbol) ? state : state.name
    end

    def render
      dict = @dict
      dict[:End] = true unless dict[:Next]
      dict
    end
  end

  class Task < State
    def initialize(name)
      super
      @dict[:Type] = "Task"
      @dict[:Resource] = $FUNCTION_ARN
      @dict[:Parameters] = {
        :Task => name,
        "Input.$" => "$",
      }
    end

    def action(&action_block)
      @action_block = action_block
    end

    def perform_action(input)
      output = input # default: pass through

      output = @action_block.call(input) if @action_block

      if @implicit_choice
        output = {} unless output
        @implicit_choice.perform_action(output)
      end

      output
    end

    def implicit_choice
      unless @implicit_choice
        @implicit_choice = Choice.new("#{name}_choice")
        $sm.add @implicit_choice
        self.next = @implicit_choice
      end
      @implicit_choice
    end
  end

  class Callback < State
    def initialize(name)
      super
      @dict[:Type] = "Task"
      @dict[:Resource] = "arn:aws:states:::lambda:invoke.waitForTaskToken"
      @dict[:Parameters] = {
        :FunctionName => function_name,
        :Payload => {
          :Task => name,
          "Input.$" => "$",
          "Token.$" => "$$.Task.Token",
        },
      }
    end

    def action(&action_block)
      @action_block = action_block
    end

    def perform_action(input, token)
      @action_block.call(input, token) if @action_block
    end
  end

  class ChoiceItem
    attr_accessor :implicit_condition_block

    def initialize(dict = {}, state = nil)
      @dict = dict
      self.next = state if state
    end

    def next=(state)
      @dict[:Next] = (state.is_a? Symbol) ? state : state.name
    end

    def render
      @dict
    end

    def perform_action(choice_name, output)
      if @implicit_condition_block
        output["#{choice_name}_#{@dict[:Next]}"] = @implicit_condition_block.call(output) ? "yes" : "no"
      end
    end
  end

  class Choice < State
    attr_reader :choices

    def initialize(name)
      super
      @choices = []
      @dict[:Type] = "Choice"
    end

    def add(item)
      @choices.push item
    end

    def add_string_matches(var, match, state)
      add ChoiceItem.new({
            :Variable => var,
            :StringMatches => match,
          }, state)
    end

    def default=(state)
      @dict[:Default] = (state.is_a? Symbol) ? state : state.name
    end

    def next=(state)
      self.default = state
    end

    def render
      dict = @dict.clone
      dict[:Choices] = @choices.map { |item| item.render }
      dict
    end

    def perform_action(output)
      @choices.each do |choice|
        choice.perform_action name, output
      end
    end
  end
end

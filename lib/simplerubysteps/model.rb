module Simplerubysteps
  $LAMBDA_FUNCTION_ARNS = ENV["LAMBDA_FUNCTION_ARNS"] ? ENV["LAMBDA_FUNCTION_ARNS"].split(",") : nil

  def pop_function_arn
    return "unknown" unless $LAMBDA_FUNCTION_ARNS
    arn = $LAMBDA_FUNCTION_ARNS.first
    $LAMBDA_FUNCTION_ARNS.delete arn
    arn
  end

  def pop_function_name
    return "unknown" unless pop_function_arn =~ /.+\:function\:(.+)/
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

    def cloudformation_config
      data = []
      states.each do |name, state|
        if state.is_a? Task or state.is_a? Callback
          data.push({
            env: {
              task: name,
            },
            iam_permissions: state.iam_permissions,
            queue: ((state.is_a? Callback) ? state.queue : nil),
          })
        end
      end
      data
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
    attr_accessor :iam_permissions

    def initialize(name)
      super
      @dict[:Type] = "Task"
      @dict[:Resource] = pop_function_arn
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
    attr_accessor :iam_permissions
    attr_accessor :queue

    def initialize(name)
      super
      @dict[:Type] = "Task"
      @dict[:Resource] = "arn:aws:states:::lambda:invoke.waitForTaskToken"
      @dict[:Parameters] = {
        :FunctionName => pop_function_name,
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

    def perform_queue_action(input, token, queue_client)
      @action_block.call(input, token, queue_client) if @action_block
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

require "simplerubysteps/version"
require "json"

module Simplerubysteps
  $FUNCTION_ARN=ENV["LAMBDA_FUNCTION_ARN"] ? ENV["LAMBDA_FUNCTION_ARN"] : "unknown"

  class StateMachine
      attr_reader :states
      attr_reader :start_at

      def initialize()
          @states = {}
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
              :States => @states.map { |name,state| [name, state.render] }.to_h
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

      def []=(key,value)
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
          @dict[:"Parameters"] = {
              :Task => name,
              "Input.$" => "$"
          }
      end

      def action(&action_block)
          @action_block = action_block
      end

      def perform_action(input)
          @action_block.call(input) if @action_block
      end
  end

  class ChoiceItem 
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
                  :StringMatches => match
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
  end

  ################################################################################

  $sm = StateMachine.new
  $tasks = []

  def task(name)
      t = $sm.add Task.new(name)

      $tasks.last.next = t if $tasks.last 

      $tasks.push t
      yield if block_given?
      $tasks.pop
  end


  def action(&action_block)
      $tasks.last.action &action_block
  end

  def transition(state)
      $tasks.last.next = state
  end

  def choice(name)
      t = $sm.add Choice.new(name)
      
      $tasks.last.next = t if $tasks.last

      $tasks.push t
      yield if block_given?
      $tasks.pop
  end

  def string_matches(var, match)
      c = ChoiceItem.new({
              :Variable => var,
              :StringMatches => match
          })

      $tasks.last.add c

      $tasks.push c
      yield if block_given?
      $tasks.pop
  end

  def default
      $tasks.push $tasks.last
      yield if block_given?
      $tasks.pop
  end
end

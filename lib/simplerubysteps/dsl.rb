require "json"

module Simplerubysteps
  $sm = StateMachine.new
  $tasks = []

  def kind(k)
    $sm.kind = k
  end

  def task(name)
    t = $sm.add Task.new(name)

    $tasks.last.next = t if $tasks.last

    $tasks.push t
    yield if block_given?
    $tasks.pop
  end

  def callback(name)
    t = $sm.add Callback.new(name)

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

  def transition_to(state, &condition_block)
    choice = $tasks.last.implicit_choice

    c = ChoiceItem.new({
      :Variable => "$.#{choice.name}_#{state}",
      :StringMatches => "yes",
    })
    c.next = state
    c.implicit_condition_block = condition_block

    choice.add c
  end

  def default_transition_to(state)
    choice = $tasks.last.implicit_choice

    choice.default = state
  end

  def iam_permissions(permissions)
    $tasks.last.iam_permissions = permissions
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
      :StringMatches => match,
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

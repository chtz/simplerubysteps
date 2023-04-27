require "json"

module Simplerubysteps
  $sm = StateMachine.new
  $tasks = []

  def kind(k)
    $sm.kind = k
  end

  def parallel(name)
    t = $sm.add Parallel.new(name)

    $tasks.last.next = t if $tasks.last

    $tasks.push t
    yield if block_given?
    $tasks.pop
  end

  def branch
    sm_backup = $sm
    tasks_backup = $tasks

    $sm = $tasks.last.new_branch
    $tasks = []

    yield if block_given?

    $sm = sm_backup
    $tasks = tasks_backup
  end

  def wait(name)
    t = $sm.add Wait.new(name)

    $tasks.last.next = t if $tasks.last

    $tasks.push t
    yield if block_given?
    $tasks.pop
  end

  def seconds(s)
    $tasks.last.seconds = s
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

  def sqs_callback(name)
    t = $sm.add Callback.new(name)
    t.queue = true

    $tasks.last.next = t if $tasks.last

    $tasks.push t
    action do |input, token, queue_client|
      queue_client.send({
        input: input,
        token: token,
      })
    end
    yield if block_given?
    $tasks.pop
  end

  def action(&action_block)
    $tasks.last.action &action_block
  end

  def transition(state)
    $tasks.last.next = state
  end

  def error_retry(interval, max, backoff, error = "States.ALL")
    $tasks.last.error_retry(interval, max, backoff)
  end

  def task_timeout(secs, state = nil)
    $tasks.last.task_timeout secs, state
  end

  def error_catch(state, error = "States.ALL")
    $tasks.last.error_catch state
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

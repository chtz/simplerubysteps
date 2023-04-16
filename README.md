# Simplerubysteps

Simplerubysteps makes it easy to manage AWS Step Functions with ruby.

* Phase I (we are here): Experimenting and exploring the problem and solution domain. The aim is to explore the DSL capabilities and user experience of the automation tool. Things will work, but may change over time. The released gem versions of Simplerubysteps are early alpha versions and therefore should not be used by anyone in production.
* Phase II: First release candidate (possibly rewritten from scratch)
* Phase III: Maintain and evolve

## Installation and Usage

### Prerequisites

* AWS CLI installed (mainly for debugging privileges)
* Configured AWS CLI profile with sufficient permissions to create IAM roles and policies, create Lambda functions, create and run Step Functions state machines, run CloudWatch log queries, etc.

### Install the gem and the srs CLI

```
gem install simplerubysteps
```

### Create an AWS Step Function State Machine with the simplerubysteps Ruby DSL

```
mkdir -p samples/hello-world-2
cd samples/hello-world-2

vi workflow.rb
```

#### Hello World State Machine (workflow.rb)

```
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
```

### Deploy the Step Functions State Machine and the Lambda function that implements the Task Actions (with srs deploy)

```
export AWS_PROFILE=<AWS CLI profile name with sufficient privileges>
cd samples/hello-world-2

srs deploy
```

### Trigger State Machine executions (with srs start)

```
export AWS_PROFILE=<AWS CLI profile name with sufficient privileges>
cd samples/hello-world-2

# Bellow: will print "Hello World!"
echo '{"hello":"Hello"}'|srs start|jq -r ".output"|jq -r ".hello_world"

# Bellow: will print "Hallo Welt!"
echo '{"hello":"Hallo"}'|srs start|jq -r ".output"|jq -r ".hello_world"
```

### Delete CloudFormation stack (with srs destroy)

```
export AWS_PROFILE=<AWS CLI profile name with sufficient privileges>
cd samples/hello-world-2

srs destroy
```

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### TODOs

* Custom IAM policies per Lambda task (e.g. to allow a task to send a message to an SQS queue)
* Workflow task/action unit test support
* Better error handling and reporting
* Improved stack update strategy (e.g. renamed or added task scenario)
* ...

## Contributing

Bug reports and pull requests are (soon - after alpha phase) welcome on GitHub at https://github.com/chtz/simplerubysteps

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

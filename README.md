# Simplerubysteps

Simplerubysteps makes it easy to manage AWS Step Functions with ruby (this is an early alpha version and should not really be used by anyone).

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
mkdir -p samples/hello-world
cd samples/hello-world

vi workflow.rb
```

#### Hello World State Machine (workflow.rb)

```
require "simplerubysteps"
include Simplerubysteps

kind "EXPRESS"

task :start do
  transition_to :even do |data|
    data["number"] % 2 == 0
  end

  default_transition_to :odd
end

task :even do
  action do |data|
    number = data["number"]

    puts "Just for the record, I've discovered an even number: #{number}"

    {
      result: "#{number} is even",
    }
  end
end

task :odd do
  action do |data|
    {
      result: "#{data["number"]} is odd",
    }
  end
end
```

### Deploy the Step Functions State Machine and the Lambda function that implements the Task Actions.

```
export AWS_PROFILE=<AWS CLI profile name with sufficient privileges>
cd samples/hello-world

srs deploy
```

### Trigger State Machine executions

```
export AWS_PROFILE=<AWS CLI profile name with sufficient privileges>
cd samples/hello-world

echo "Enter a number"
read NUMBER

echo "{\"number\":$NUMBER}" | srs start | jq -r ".output" | jq -r ".result"
# Above: will print "123 is odd" for input "123"
```

### Delete CloudFormation stack

```
export AWS_PROFILE=<AWS CLI profile name with sufficient privileges>

srs destroy
```

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### TODOs

* Custom IAM policies per Lambda task (e.g. to allow a task to send a message to an SQS queue)
* Workflow action unit test support
* Better error handling and reporting
* ...

## Contributing

Bug reports and pull requests are (soon - after alpha phase) welcome on GitHub at https://github.com/chtz/simplerubysteps

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

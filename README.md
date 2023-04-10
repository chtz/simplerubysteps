# Simplerubysteps

Simplerubysteps simplifies the administration of AWS Step Functions with ruby (eventually - this is an early alpha version)

This is software in the experimental stage and should not really be used by anyone. Be warned.

## Installation

Prerequisites (for alpha version):
* Linux-like environment (the deployment tools are currently implemented with shell scripts)
* AWS CLI installed

Add this line to your application's Gemfile:

```ruby
require "simplerubysteps"
```

And install the gem:

    $ gem install simplerubysteps

## Usage

### Create AWS Step Functions State Machine with ruby DSL

```
cd samples/sample1
vi workflow.rb
```

### Create CloudFormation stack with Step Functions State Machine and supporting Lambda functions

```
export AWS_PROFILE=...
cd samples/sample1
simplerubysteps-deploy
```

### Trigger State Machine Execution and wait for completion

```
export AWS_PROFILE=...          
cd samples/sample1
echo '{"foo": "James Bond"}' | simplerubysteps-workflow-run
```

### Delete CloudFormation stack

```
export AWS_PROFILE=...
cd samples/sample1
simplerubysteps-destroy
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. 

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are (soon - after alpha phase) welcome on GitHub at https://github.com/chtz/simplerubysteps

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

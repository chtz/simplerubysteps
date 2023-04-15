# Simplerubysteps

Simplerubysteps makes it easy to manage AWS Step Functions with ruby (this is an early alpha version and should not really be used by anyone).

## Installation

Prerequisites:
* AWS CLI installed and configured (profiles)

## Usage

### Install the gem and the simplerubysteps CLI

```
gem install simplerubysteps
```

### Create AWS Step Functions State Machine with ruby DSL

```
cd samples/sample1
vi workflow.rb
```

### Create CloudFormation stack with Step Functions State Machine and supporting Lambda function

```
export AWS_PROFILE=...
cd samples/sample1
simplerubysteps deploy
```

### Trigger State Machine Execution and wait for completion

```
export AWS_PROFILE=...          
cd samples/sample1

./start-directbranch.sh

./sample-task-worker.sh &
./start-callbackbranch.sh
```

### Delete CloudFormation stack

```
export AWS_PROFILE=...
cd samples/sample1
simplerubysteps destroy
```

## Development

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### TODOs

* Custom IAM policies per Lambda task
* Workflow action unit test support
* ...

## Contributing

Bug reports and pull requests are (soon - after alpha phase) welcome on GitHub at https://github.com/chtz/simplerubysteps

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

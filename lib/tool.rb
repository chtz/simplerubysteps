require "aws-sdk-cloudformation"
require "aws-sdk-s3"
require "aws-sdk-states"
require "digest"
require "zip"
require "tempfile"
require "json"
require "optparse"

$cloudformation_client = Aws::CloudFormation::Client.new
$s3_client = Aws::S3::Client.new
$states_client = Aws::States::Client.new

def stack_outputs(stack_name)
  begin
    response = $cloudformation_client.describe_stacks(stack_name: stack_name)
    outputs = {}
    response.stacks.first.outputs.each do |output|
      outputs[output.output_key] = output.output_value
    end
    outputs
  rescue Aws::CloudFormation::Errors::ServiceError => error
    return nil if error.message =~ /Stack .* does not exist/
    raise error
  end
end

def stack_params(stack_name, template, parameters)
  params = {
    stack_name: stack_name,
    template_body: template,
    capabilities: ["CAPABILITY_IAM", "CAPABILITY_NAMED_IAM"],
    parameters: [],
  }
  parameters.each do |k, v|
    params[:parameters].push({
      parameter_key: k,
      parameter_value: v,
    })
  end
  params
end

def stack_create(stack_name, template, parameters)
  $cloudformation_client.create_stack(stack_params(stack_name, template, parameters))
  $cloudformation_client.wait_until(:stack_create_complete, stack_name: stack_name)
  stack_outputs(stack_name)
end

def stack_update(stack_name, template, parameters)
  begin
    $cloudformation_client.update_stack(stack_params(stack_name, template, parameters))
    $cloudformation_client.wait_until(:stack_update_complete, stack_name: stack_name)
    stack_outputs(stack_name)
  rescue Aws::CloudFormation::Errors::ServiceError => error
    return stack_outputs(stack_name).merge({ :no_update => true }) if error.message =~ /No updates are to be performed/
    raise unless error.message =~ /No updates are to be performed/
  end
end

def upload_to_s3(bucket, key, body)
  $s3_client.put_object(
    bucket: bucket,
    key: key,
    body: body,
  )
end

def upload_file_to_s3(bucket, key, file_path)
  File.open(file_path, "rb") do |file|
    upload_to_s3(bucket, key, file)
  end
end

def empty_s3_bucket(bucket_name)
  $s3_client.list_objects_v2(bucket: bucket_name).contents.each do |object|
    $s3_client.delete_object(bucket: bucket_name, key: object.key)
  end
end

def create_zip(zip_file, files_by_name)
  Zip::File.open(zip_file, create: true) do |zipfile|
    base_dir = File.expand_path(File.dirname(__FILE__))
    files_by_name.each do |n, f|
      zipfile.add n, f
    end
  end
end

def dir_files(base_dir, glob)
  files_by_name = {}
  base_dir = File.expand_path(base_dir)
  Dir.glob("#{base_dir}/#{glob}").select { |path| File.file?(path) }.each do |f|
    files_by_name[File.expand_path(f)[base_dir.length + 1..-1]] = f
  end
  files_by_name
end

def stack_name_from_current_dir
  File.basename(File.expand_path("."))
end

def workflow_files
  dir_files ".", "**/*.rb"
end

def my_lib_files
  dir_files File.dirname(__FILE__), "**/*.rb"
end

def cloudformation_template
  File.open("#{File.dirname(__FILE__)}/statemachine.yaml", "r") do |file|
    return file.read
  end
end

def destroy
  current_stack_outputs = stack_outputs(stack_name_from_current_dir)
  deploy_bucket = current_stack_outputs["DeployBucket"]
  rause "No CloudFormation stack to destroy" unless deploy_bucket

  empty_s3_bucket deploy_bucket

  puts "Bucket emptied: #{deploy_bucket}"

  $cloudformation_client.delete_stack(stack_name: stack_name_from_current_dir)
  $cloudformation_client.wait_until(:stack_delete_complete, stack_name: stack_name_from_current_dir)

  puts "Stack deleted"
end

def deploy(workflow_type)
  current_stack_outputs = stack_outputs(stack_name_from_current_dir)

  unless current_stack_outputs
    current_stack_outputs = stack_create(stack_name_from_current_dir, cloudformation_template, {
      "DeployLambda" => "no",
      "DeployStepfunctions" => "no",
      "LambdaS3" => "",
      "StepFunctionsS3" => "",
      "StateMachineType" => "",
    })

    puts "Deployment bucket created"
  end

  deploy_bucket = current_stack_outputs["DeployBucket"]
  puts "Deployment bucket: #{deploy_bucket}"

  function_zip_temp = Tempfile.new("function")
  create_zip function_zip_temp.path, my_lib_files.merge(workflow_files)
  lambda_sha = Digest::SHA1.file function_zip_temp.path
  lambda_zip_name = "function-#{lambda_sha}.zip"
  upload_file_to_s3 deploy_bucket, lambda_zip_name, function_zip_temp.path
  puts "Uploaded: #{lambda_zip_name}"

  unless current_stack_outputs["LambdaFunctionARN"]
    current_stack_outputs = stack_update(stack_name_from_current_dir, cloudformation_template, {
      "DeployLambda" => "yes",
      "DeployStepfunctions" => "no",
      "LambdaS3" => lambda_zip_name,
      "StepFunctionsS3" => "",
      "StateMachineType" => "",
    })

    puts "Lambda function created"
  end

  lambda_arn = current_stack_outputs["LambdaFunctionARN"]
  puts "Lambda function: #{lambda_arn}"

  state_machine_json = JSON.parse(`LAMBDA_FUNCTION_ARN=#{lambda_arn} ruby -e 'require "./workflow.rb";puts $sm.render.to_json'`).to_json
  state_machine_json_sha = Digest::SHA1.hexdigest state_machine_json
  state_machine_json_name = "statemachine-#{state_machine_json_sha}.json"
  upload_to_s3 deploy_bucket, state_machine_json_name, state_machine_json
  puts "Uploaded: #{state_machine_json_name}"

  current_stack_outputs = stack_update(stack_name_from_current_dir, cloudformation_template, {
    "DeployLambda" => "yes",
    "DeployStepfunctions" => "yes",
    "LambdaS3" => lambda_zip_name,
    "StepFunctionsS3" => state_machine_json_name,
    "StateMachineType" => workflow_type,
  })

  if current_stack_outputs[:no_update]
    puts "Stack not updated"
  else
    puts "Stack updated"
  end

  puts "State machine: #{current_stack_outputs["StepFunctionsStateMachineARN"]}"
end

def start_sync_execution(state_machine_arn, input)
  $states_client.start_sync_execution(
    state_machine_arn: state_machine_arn,
    input: input,
  )
end

def start_async_execution(state_machine_arn, input)
  $states_client.start_execution(
    state_machine_arn: state_machine_arn,
    input: input,
  )
end

def describe_execution(execution_arn)
  $states_client.describe_execution(
    execution_arn: execution_arn,
  )
end

def wait_for_async_execution_completion(execution_arn)
  response = nil

  loop do
    response = describe_execution(execution_arn)
    status = response.status

    break if %w[SUCCEEDED FAILED TIMED_OUT].include?(status)

    sleep 5
  end

  response
end

def start(workflow_type, wait = true, input = $stdin)
  current_stack_outputs = stack_outputs(stack_name_from_current_dir)
  state_machine_arn = current_stack_outputs["StepFunctionsStateMachineARN"]
  raise "State Machine is not deployed" unless state_machine_arn

  input_json = JSON.parse(input.read).to_json

  if workflow_type == "STANDARD"
    start_response = start_async_execution(state_machine_arn, input_json)

    unless wait
      puts start_response.to_json
    else
      execution_arn = start_response.execution_arn

      puts wait_for_async_execution_completion(execution_arn).to_json
    end
  elsif workflow_type == "EXPRESS"
    puts start_sync_execution(state_machine_arn, input_json).to_json
  else
    raise "Unknown state machine type: #{workflow_type}"
  end
end

def send_task_success(task_token, output = $stdin)
  raise "No token" unless task_token

  output_json = JSON.parse(output.read).to_json

  puts $states_client.send_task_success(
    task_token: task_token,
    output: output_json,
  ).to_json
end

options = {
  :workflow_type => "STANDARD",
  :wait => false,
  :input => $stdin,
}

subcommands = {
  "deploy" => OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} deploy [options]"

    opts.on("--type VALUE", "STANDARD (default) or EXPRESS") do |value|
      options[:workflow_type] = value
    end

    opts.on("-h", "--help", "Display this help message") do
      puts opts
      exit
    end
  end,
  "destroy" => OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} destroy [options]"

    opts.on("-h", "--help", "Display this help message") do
      puts opts
      exit
    end
  end,
  "start" => OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} start [options]"

    opts.on("--type VALUE", "STANDARD (default) or EXPRESS") do |value|
      options[:workflow_type] = value
    end

    opts.on("--wait VALUE", "true (default and always true for EXPRESS) or false (default for STANDARD)") do |value|
      options[:wait] = "true" == value
    end

    opts.on("--input VALUE", "/path/to/file (STDIN will be used per default)") do |value|
      options[:input] = File.new(value)
    end

    opts.on("-h", "--help", "Display this help message") do
      puts opts
      exit
    end
  end,

  "task-success" => OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} task-success [options]"

    opts.on("--input VALUE", "/path/to/file (STDIN will be used per default)") do |value|
      options[:input] = File.new(value)
    end

    opts.on("--token VALUE", "The task token") do |value|
      options[:token] = value
    end

    opts.on("-h", "--help", "Display this help message") do
      puts opts
      exit
    end
  end,
}

global = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [command] [options]"
  opts.separator ""
  opts.separator "Commands:"
  opts.separator "    deploy        Create Step Functions State Machine"
  opts.separator "    destroy       Delete Step Functions State Machine"
  opts.separator "    start         Start State Machine execution"
  opts.separator "    task-success  Continue Start State Machine execution"
  opts.separator ""

  opts.on_tail("-h", "--help", "Display this help message") do
    puts opts
    exit
  end
end

begin
  global.order!(ARGV)
  command = ARGV.shift
  options[:command] = command
  subcommands.fetch(command).parse!(ARGV)
rescue KeyError
  puts "Unknown command: '#{command}'"
  puts
  puts global
  exit 1
rescue OptionParser::ParseError => error
  puts error.message
  puts subcommands.fetch(command)
  exit 1
end

if options[:command] == "deploy"
  deploy options[:workflow_type]
elsif options[:command] == "start"
  start options[:workflow_type], options[:wait], options[:input]
elsif options[:command] == "task-success"
  send_task_success options[:token], options[:input]
elsif options[:command] == "destroy"
  destroy
end

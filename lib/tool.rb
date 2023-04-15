require "aws-sdk-cloudformation"
require "aws-sdk-s3"
require "digest"
require "zip"
require "tempfile"
require "json"

$cloudformation_client = Aws::CloudFormation::Client.new
$s3_client = Aws::S3::Client.new

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
  rescue Aws::CloudFormation::Errors::ServiceError => error
    raise error unless error.message =~ /No updates are to be performed/
  end
  stack_outputs(stack_name)
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

def my_lib_files
  dir_files File.dirname(__FILE__), "**/*.rb"
end

def cloudformation_template
  File.open("#{File.dirname(__FILE__)}/statemachine.yaml", "r") do |file|
    return file.read
  end
end

def workflow_files
  dir_files ".", "**/*.rb"
end

def upload_file_to_s3(bucket, key, file_path)
  File.open(file_path, "rb") do |file|
    $s3_client.put_object(
      bucket: bucket,
      key: key,
      body: file,
    )
  end
end

def upload_to_s3(bucket, key, body)
  $s3_client.put_object(
    bucket: bucket,
    key: key,
    body: body,
  )
end

def stack_name_from_current_dir
  File.basename(File.expand_path("."))
end

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
LAMBDA_SHA = Digest::SHA1.file function_zip_temp.path
UPLOADED_LAMBDA_ZIP = "function-#{LAMBDA_SHA}.zip"
upload_file_to_s3 deploy_bucket, UPLOADED_LAMBDA_ZIP, function_zip_temp.path
puts "Uploaded: #{UPLOADED_LAMBDA_ZIP}"

unless current_stack_outputs["LambdaFunctionARN"]
  current_stack_outputs = stack_update(stack_name_from_current_dir, cloudformation_template, {
    "DeployLambda" => "yes",
    "DeployStepfunctions" => "no",
    "LambdaS3" => UPLOADED_LAMBDA_ZIP,
    "StepFunctionsS3" => "",
    "StateMachineType" => "",
  })

  puts "Lambda function created"
end

lambda_arn = current_stack_outputs["LambdaFunctionARN"]
puts "Lambda function: #{lambda_arn}"

WF_TYPE = "STANDARD"

state_machine_json = JSON.parse(`LAMBDA_FUNCTION_ARN=#{lambda_arn} ruby -e 'require "./workflow.rb";puts $sm.render.to_json'`).to_json
STATE_MACHINE_JSON_SHA = Digest::SHA1.hexdigest state_machine_json
UPLOADED_STATE_MACHINE_JSON = "statemachine-#{STATE_MACHINE_JSON_SHA}.json"
upload_to_s3 deploy_bucket, UPLOADED_STATE_MACHINE_JSON, state_machine_json
puts "Uploaded: #{UPLOADED_STATE_MACHINE_JSON}"

current_stack_outputs = stack_update(stack_name_from_current_dir, cloudformation_template, {
  "DeployLambda" => "yes",
  "DeployStepfunctions" => "yes",
  "LambdaS3" => UPLOADED_LAMBDA_ZIP,
  "StepFunctionsS3" => UPLOADED_STATE_MACHINE_JSON,
  "StateMachineType" => WF_TYPE,
})

# FIXME indicate updated yes/no

puts "State machine: #{current_stack_outputs["StepFunctionsStateMachineARN"]}"

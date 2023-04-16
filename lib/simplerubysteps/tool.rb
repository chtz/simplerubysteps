require "simplerubysteps/version"
require "simplerubysteps/cloudformation"
require "aws-sdk-cloudformation"
require "aws-sdk-s3"
require "aws-sdk-states"
require "digest"
require "zip"
require "tempfile"
require "json"
require "optparse"
require "aws-sdk-cloudwatchlogs"
require "time"
require "thread"

module Simplerubysteps
  class Tool
    def initialize
      @cloudformation_client = Aws::CloudFormation::Client.new
      @s3_client = Aws::S3::Client.new
      @states_client = Aws::States::Client.new
      @logs_client = Aws::CloudWatchLogs::Client.new
    end

    def tail_follow_logs(log_group_name, extract_pattern = nil) # FIXME too hacky
      Signal.trap("INT") do
        exit
      end

      first_event_time = Time.now.to_i * 1000

      next_tokens = {}
      first_round = true
      loop do
        log_streams = @logs_client.describe_log_streams(
          log_group_name: log_group_name,
          order_by: "LastEventTime",
          descending: true,
        ).log_streams

        log_streams.each do |log_stream|
          get_log_events_params = {
            log_group_name: log_group_name,
            log_stream_name: log_stream.log_stream_name,
          }

          if next_tokens.key?(log_stream.log_stream_name)
            get_log_events_params[:next_token] = next_tokens[log_stream.log_stream_name]
          else
            get_log_events_params[:start_time] = first_round ? log_stream.last_event_timestamp : first_event_time
          end

          response = @logs_client.get_log_events(get_log_events_params)

          response.events.each do |event|
            if event.timestamp >= first_event_time
              if extract_pattern
                if /#{extract_pattern}/ =~ event.message
                  puts $1
                  exit
                end
              else
                puts "#{Time.at(event.timestamp / 1000).utc} - #{log_stream.log_stream_name} - #{event.message}"
              end
            end
          end

          next_tokens[log_stream.log_stream_name] = response.next_forward_token
        end

        sleep 5

        first_round = false
      end
    end

    def stack_outputs(stack_name)
      begin
        response = @cloudformation_client.describe_stacks(stack_name: stack_name)
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
      @cloudformation_client.create_stack(stack_params(stack_name, template, parameters))
      @cloudformation_client.wait_until(:stack_create_complete, stack_name: stack_name)
      stack_outputs(stack_name)
    end

    def stack_update(stack_name, template, parameters)
      begin
        @cloudformation_client.update_stack(stack_params(stack_name, template, parameters))
        @cloudformation_client.wait_until(:stack_update_complete, stack_name: stack_name)
        stack_outputs(stack_name)
      rescue Aws::CloudFormation::Errors::ServiceError => error
        return stack_outputs(stack_name).merge({ :no_update => true }) if error.message =~ /No updates are to be performed/
        raise unless error.message =~ /No updates are to be performed/
      end
    end

    def list_stacks_with_prefix(prefix)
      stack_list = []
      next_token = nil
      loop do
        response = @cloudformation_client.list_stacks({
          next_token: next_token,
          stack_status_filter: %w[
            CREATE_COMPLETE
            UPDATE_COMPLETE
            ROLLBACK_COMPLETE
          ],
        })

        response.stack_summaries.each do |stack|
          if stack.stack_name.start_with?(prefix)
            stack_list << stack.stack_name
          end
        end

        next_token = response.next_token
        break if next_token.nil?
      end

      stack_list
    end

    def most_recent_stack_with_prefix(prefix)
      stack_list = {}
      next_token = nil
      loop do
        response = @cloudformation_client.list_stacks({
          next_token: next_token,
          stack_status_filter: %w[
            CREATE_COMPLETE
            UPDATE_COMPLETE
            ROLLBACK_COMPLETE
          ],
        })

        response.stack_summaries.each do |stack|
          if stack.stack_name.start_with?(prefix)
            stack_list[stack.creation_time] = stack.stack_name
          end
        end

        next_token = response.next_token
        break if next_token.nil?
      end

      stack_list.empty? ? nil : stack_list[stack_list.keys.sort.last]
    end

    def upload_to_s3(bucket, key, body)
      @s3_client.put_object(
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
      @s3_client.list_objects_v2(bucket: bucket_name).contents.each do |object|
        @s3_client.delete_object(bucket: bucket_name, key: object.key)
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

    def unversioned_stack_name_from_current_dir
      File.basename(File.expand_path("."))
    end

    def workflow_files
      dir_files ".", "**/*.rb"
    end

    def workflow_files_hash
      file_hashes = []
      workflow_files.each do |name, file|
        file_hashes.push Digest::SHA1.file(file)
      end
      Digest::SHA1.hexdigest file_hashes.join(",")
    end

    def versioned_stack_name_from_current_dir
      "#{unversioned_stack_name_from_current_dir}-#{workflow_files_hash()[0...8]}"
    end

    def my_lib_files
      files = dir_files(File.dirname(__FILE__) + "/..", "**/*.rb").filter { |f| not(f =~ /cloudformation\.rb|tool\.rb/) }
    end

    def cloudformation_template(lambda_cf_config, deploy_state_machine)
      data = {
        state_machine: deploy_state_machine,
      }

      if lambda_cf_config
        data[:functions] = lambda_cf_config # see StateMachine.cloudformation_config()
      end

      Simplerubysteps::cloudformation_yaml(data)
    end

    def log(extract_pattern = nil)
      stack = most_recent_stack_with_prefix "#{unversioned_stack_name_from_current_dir}-"
      raise "State Machine is not deployed" unless stack

      current_stack_outputs = stack_outputs(stack)

      last_thread = nil
      (0..current_stack_outputs["LambdaCount"].to_i - 1).each do |i|
        function_name = current_stack_outputs["LambdaFunctionName#{i}"]
        last_thread = Thread.new do # FIXME Less brute force approach (?)
          tail_follow_logs "/aws/lambda/#{function_name}", extract_pattern
        end
      end
      last_thread.join if last_thread
    end

    def destroy
      list_stacks_with_prefix("#{unversioned_stack_name_from_current_dir}-").each do |stack|
        current_stack_outputs = stack_outputs(stack)
        deploy_bucket = current_stack_outputs["DeployBucket"]
        rause "No CloudFormation stack to destroy" unless deploy_bucket

        empty_s3_bucket deploy_bucket

        puts "Bucket emptied: #{deploy_bucket}"

        @cloudformation_client.delete_stack(stack_name: stack)
        @cloudformation_client.wait_until(:stack_delete_complete, stack_name: stack)

        puts "Stack deleted: #{stack}"
      end
    end

    def deploy
      current_stack_outputs = stack_outputs(versioned_stack_name_from_current_dir)

      unless current_stack_outputs
        current_stack_outputs = stack_create(versioned_stack_name_from_current_dir, cloudformation_template(nil, false), {})

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

      lambda_cf_config = JSON.parse(`ruby -e 'require "./workflow.rb";puts $sm.cloudformation_config.to_json'`)

      if current_stack_outputs["LambdaCount"].nil? or current_stack_outputs["LambdaCount"].to_i != lambda_cf_config.length # FIXME Do not implicitly delete the state machine when versioning is turned off.
        current_stack_outputs = stack_update(versioned_stack_name_from_current_dir, cloudformation_template(lambda_cf_config, false), {
          "LambdaS3" => lambda_zip_name,
        })

        puts "Lambda function created"
      end

      lambda_arns = []
      (0..current_stack_outputs["LambdaCount"].to_i - 1).each do |i|
        lambda_arn = current_stack_outputs["LambdaFunctionARN#{i}"]

        puts "Lambda function: #{lambda_arn}"

        lambda_arns.push lambda_arn
      end

      workflow_type = `ruby -e 'require "./workflow.rb";puts $sm.kind'`.strip

      state_machine_json = JSON.parse(`LAMBDA_FUNCTION_ARNS=#{lambda_arns.join(",")} ruby -e 'require "./workflow.rb";puts $sm.render.to_json'`).to_json
      state_machine_json_sha = Digest::SHA1.hexdigest state_machine_json
      state_machine_json_name = "statemachine-#{state_machine_json_sha}.json"
      upload_to_s3 deploy_bucket, state_machine_json_name, state_machine_json

      puts "Uploaded: #{state_machine_json_name}"

      current_stack_outputs = stack_update(versioned_stack_name_from_current_dir, cloudformation_template(lambda_cf_config, true), { # FIXME when versioning is turned off: 1) create additional lambdas 2) update State Machine
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
      @states_client.start_sync_execution(
        state_machine_arn: state_machine_arn,
        input: input,
      )
    end

    def start_async_execution(state_machine_arn, input)
      @states_client.start_execution(
        state_machine_arn: state_machine_arn,
        input: input,
      )
    end

    def describe_execution(execution_arn)
      @states_client.describe_execution(
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

    def start(wait = true, input = $stdin)
      stack = most_recent_stack_with_prefix "#{unversioned_stack_name_from_current_dir}-"
      raise "State Machine is not deployed" unless stack

      current_stack_outputs = stack_outputs(stack)
      state_machine_arn = current_stack_outputs["StepFunctionsStateMachineARN"]

      input_json = JSON.parse(input.read).to_json

      if current_stack_outputs["StateMachineType"] == "STANDARD"
        start_response = start_async_execution(state_machine_arn, input_json)

        unless wait
          puts start_response.to_json
        else
          execution_arn = start_response.execution_arn

          puts wait_for_async_execution_completion(execution_arn).to_json
        end
      elsif current_stack_outputs["StateMachineType"] == "EXPRESS"
        puts start_sync_execution(state_machine_arn, input_json).to_json
      else
        raise "Unknown state machine type: #{current_stack_outputs["StateMachineType"]}"
      end
    end

    def send_task_success(task_token, output = $stdin)
      raise "No token" unless task_token

      output_json = JSON.parse(output.read).to_json

      puts @states_client.send_task_success(
        task_token: task_token,
        output: output_json,
      ).to_json
    end

    def run
      options = {
        :wait => false,
        :input => $stdin,
      }

      subcommands = {
        "deploy" => OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} deploy [options]"

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
        "log" => OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} log [options]"

          opts.on("--extract_pattern VALUE", "Wait for and extract pattern") do |value|
            options[:extract_pattern] = value
          end

          opts.on("-h", "--help", "Display this help message") do
            puts opts
            exit
          end
        end,
        "start" => OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} start [options]"

          opts.on("--wait", "Wait for STANDARD state machine to complete") do
            options[:wait] = true
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
        opts.separator "Commands (#{Simplerubysteps::VERSION}):"
        opts.separator "    deploy        Create Step Functions State Machine"
        opts.separator "    destroy       Delete Step Functions State Machine"
        opts.separator "    log           Continuously prints Lambda function log output"
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
        deploy
      elsif options[:command] == "start"
        start options[:wait], options[:input]
      elsif options[:command] == "log"
        log options[:extract_pattern]
      elsif options[:command] == "task-success"
        send_task_success options[:token], options[:input]
      elsif options[:command] == "destroy"
        destroy
      end
    end
  end
end

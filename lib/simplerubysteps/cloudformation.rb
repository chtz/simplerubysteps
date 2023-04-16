require "erb"

module Simplerubysteps
  CLOUDFORMATION_ERB_TEMPLATE = <<-YAML
---
AWSTemplateFormatVersion: "2010-09-09"

<% if resources[:functions] %>
Parameters:  
  LambdaS3:
    Description: LambdaS3.
    Type: String
<% end %>

<% if resources[:state_machine] %>
  StepFunctionsS3:
    Description: StepFunctionsS3.
    Type: String
  StateMachineType:
    Description: StateMachineType.
    Type: String
<% end %>

Resources:
  DeployBucket:
    Type: AWS::S3::Bucket

<% if resources[:functions] %>
<% resources[:functions].each_with_index do |resource, index| %>
  LambdaFunction<%= index %>:
    Type: "AWS::Lambda::Function"
    Properties:
      Code:
        S3Bucket: !Ref DeployBucket
        S3Key: !Ref LambdaS3
      Handler: function.handler      
      Role: !GetAtt MyLambdaRole<%= index %>.Arn
      Runtime: ruby2.7
      Environment:
        Variables:
<% resource["env"].each do |k, v| %>        
          <%= k %>: <%= v.inspect %>
<% end %>
  LogGroup<%= index %>:
    Type: AWS::Logs::LogGroup
    Properties:
      LogGroupName: !Sub "/aws/lambda/${LambdaFunction<%= index %>}"
      RetentionInDays: 7  
  MyLambdaRole<%= index %>:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service: lambda.amazonaws.com
            Action:
              - sts:AssumeRole
      Policies:
        - PolicyName: lambda-policy
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: arn:aws:logs:*:*:*
<% if resource["iam_permissions"] %>
  MyCustomPolicy<%= index %>:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: !Ref LambdaFunction<%= index %>
      Roles:
        - !Ref MyLambdaRole<%= index %>
      PolicyDocument: <%= resource["iam_permissions"].inspect %>
<% end %>
<% end %>
<% end %>
  
<% if resources[:state_machine] %>
  StepFunctionsStateMachine:
    Type: "AWS::StepFunctions::StateMachine"
    Properties:
      DefinitionS3Location:
        Bucket: !Ref DeployBucket
        Key: !Ref StepFunctionsS3
      RoleArn: !GetAtt StepFunctionsRole.Arn
      StateMachineType: !Ref StateMachineType
  StepFunctionsRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service: states.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: StepFunctionsPolicy
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: arn:aws:logs:*:*:*
              - Effect: Allow
                Action:
                  - lambda:InvokeFunction
                Resource: 
<% resources[:functions].each_with_index do |resource, index| %>                
                  - !GetAtt LambdaFunction<%= index %>.Arn
<% end %>                  
<% end %>

Outputs:
  DeployBucket:
    Value: !Ref DeployBucket

<% if resources[:functions] %>    
  LambdaCount:
    Value: <%= resources[:functions].length %>
<% resources[:functions].each_with_index do |resource, index| %>    
  LambdaRoleARN<%= index %>:
    Value: !GetAtt MyLambdaRole<%= index %>.Arn
  LambdaFunctionARN<%= index %>:
    Value: !GetAtt LambdaFunction<%= index %>.Arn
  LambdaFunctionName<%= index %>:
    Value: !Ref LambdaFunction<%= index %>
<% end %>    
<% end %>  

<% if resources[:state_machine] %>
  StepFunctionsStateMachineARN:
    Value: !GetAtt StepFunctionsStateMachine.Arn
  StateMachineType:
    Value: !Ref StateMachineType
  StepFunctionsRoleARN:
    Value: !GetAtt StepFunctionsRole.Arn
<% end %>    
YAML

  def self.cloudformation_yaml(resources)
    template = ERB.new(CLOUDFORMATION_ERB_TEMPLATE)
    template.result(binding)
  end
end

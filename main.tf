terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_sqs_queue" "DwDLQ" {
  name = "DwDLQ"
  tags = {
    "Environment" = "development"
  }
}

resource "aws_sqs_queue" "Dw" {
  name = "Dw"
  tags = {
    "Environment" = "development"
  }

  delay_seconds              = 0
  max_message_size           = 262144
  receive_wait_time_seconds  = 0
  message_retention_seconds  = 345600
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    maxReceiveCount     = 10
    deadLetterTargetArn = aws_sqs_queue.DwDLQ.arn
  })

  policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": "*",
        "Action": "sqs:SendMessage",
        "Resource": "arn:aws:sqs:*:*:Dw",
        "Condition": {
          "ArnEquals": { "aws:SourceArn": "${aws_s3_bucket.mvc-dw-2021.arn}" }
        }
      }
    ]
  }
  POLICY
}

resource "aws_s3_bucket" "mvc-dw-2021" {
  bucket = "mvc-dw-2021"
  tags = {
    "Environment" = "development"
  }
}

resource "aws_s3_bucket_notification" "notfication-dw-2021" {
  bucket = aws_s3_bucket.mvc-dw-2021.id

  queue {
    queue_arn = aws_sqs_queue.Dw.arn
    events    = ["s3:ObjectCreated:Put"]
  }
}

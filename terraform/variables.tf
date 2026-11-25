variable "aws_region" {
  description = "AWS region where the EC2 instance is created."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone used to select the default subnet."
  type        = string
  default     = "us-east-1f"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID used to launch the EC2 instance."
  type        = string
  default     = "ami-0fbc7ac82ff7690bc"
}

variable "instance_name" {
  description = "Value of the Name tag on the EC2 instance."
  type        = string
  default     = "fairoz-demo"
}

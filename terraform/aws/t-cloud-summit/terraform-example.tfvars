# 
# Dynatrace credentials
# 
dt_tenant     = ""
dt_api_token  = ""
dt_paas_token = ""

#
# Custom VPC
#
# If left empty, a VPC will be created for you. If you want to repurpose an existing VPC
# simply provide it's id and the id of a subnet the EC2 instances will be launched in.
#
vpc_id    = ""
subnet_id = ""

#
# Use case
#
attendee_configs_csv_path = "./attendees-example.csv"
extra_vars                = {}

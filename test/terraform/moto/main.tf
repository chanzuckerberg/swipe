module "swipetest" {
  source                   = "../../.."
  mock                     = true
  call_cache               = true
  miniwdl_dir              = "${path.cwd}/tmp"
  app_name                 = "swipe-test"
  batch_ec2_instance_types = ["optimal"]
  sqs_queues = {
    "notifications" : { "dead_letter" : false }
  }
  call_cache = true
  sfn_template_files = {
    "stage-test" : "../../stage-test.yml"
  }
  stage_memory_defaults = {
    "Run" : { "spot" : 12800, "on_demand" : 256000 },
    "One" : { "spot" : 12800, "on_demand" : 256000 },
    "Two" : { "spot" : 12800, "on_demand" : 256000 },
  }
}

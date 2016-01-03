# jenkins-job-orchestrator

I had to write this quick hack from scratch, a few times in the past (e.g. when changing jobs etc), finally decided 
to store it in github and just modify as necessary from now on.. This script is not something that will work out of 
the box, it's environment/Jenkins setup specific

I usually name jenkins jobs following some pattern, e.g.: 
      product_framework_architecture_trunkorbranch_job-purpose etc
as it makes writing automations for bulk changes in jenkins so much easier

I sed replaced keywords from these patterns before uploading this script on github

Some background about this script:
Quite often I happen to work with developers who are not very familiar with jenkins, in order to avoid confusion &
make things more user friendly for them I usually create automations that work using a software repository 
name - I find that many times that works better for them. This script is actually part of 'master' a rundeck job. 
I prefer creating one-stop-shop jobs that take care of building software/setting up environments etc, very easily 
by just providing the repository or product and ticking a few boxes on the rundeck gui. Now it should make more 
sense about why I'm doing all that string manipulation in the script.. Maybe one day I'll turn this into something 
more generic that can be used by everyone..
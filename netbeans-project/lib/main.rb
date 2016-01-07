#!/usr/bin/ruby
###!/usr/bin/ruby -w

# Copyright (C) 2016 Dimitrios <dimitrios.work@outlook.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

#fixme -- nokogiri exceptions
#fixme -- remove 'debug' puts statements
#todo -- ponder about using abort_on_exception
#todo -- min-free jenkins workers option (parallel runs are constrained by the minimum free workers option)
#todo -- commandline args

require 'rest-client'
require 'nokogiri'
require 'mime-types'
require 'netrc'
require 'http-cookie'
require 'logger'

module TriggerMultipleJenkinsJobs

  class LogDelegator
    def initialize 
      @CONSOLE=Logger.new(STDERR)
      @LOGFILE=Logger.new('./trigger_multiple_jenkins_jobs.log', 3, 10000000 )
      @CONSOLE.level=Logger::INFO
      @LOGFILE.level=Logger::DEBUG
    end
    
    def info(text)
      @CONSOLE.send(__callee__.to_sym, text)
      @LOGFILE.send(__callee__.to_sym, text)
    end

    for level in ['debug', 'warn', 'error', 'fatal']
      alias_method level, 'info'
    end

    def close
      @CONSOLE.close
      @LOGFILE.close
    end
  end

  def init
    options=read_conf
    commandline_args, debug, never_exit = args_init

    options[:debug]=debug
    options[:never_exit]=never_exit

    return options, commandline_args
  end

  def read_conf
    options={:credentials=>{:username=>'', :password=>''}, :url=>'', :thread_count=>'', :minfree_workers=>''}
    File.read('./jenkins.conf').split("\n").each do |line|
      case line.split(" ")[0]
      when 'url'
        options[:url] = line.split(" ")[1]
      when 'username'
        options[:credentials][:username] = line.split(" ")[1]
      when 'password'
        options[:credentials][:password] = line.split(" ")[1]
      when 'thread_count'
        options[:thread_count] = line.split(" ")[1].to_i
      when 'minfree_workers'
        options[:minfree_workers] = line.split(" ")[1].to_i
      else
        @logger.fatal("unknown config option #{line.split(" ")[0]}. Options hash contains: #{options}. Initiating crash and burn procedure..")
        exit 1
      end
    end

    options.each_key do |key|
      if options[key] == ''
        @logger.fatal("no config value for #{key}, exiting..")
        exit 1
      end
    end

    return options

  rescue Errno::EACCES => e
    @logger.fatal('couldn\'t read the config file, exiting..')
    @logger.debug("the exception: #{e}")
    @logger.debug("and the backtrace: #{e.backtrace.inspect}")
    exit 1
  rescue Errno::ENOENT => e
    @logger.fatal('couldn\'t find the config file, exiting..')
    @logger.debug("the exception: #{e}")
    @logger.debug("and the backtrace: #{e.backtrace.inspect}")
    exit 1
  rescue IOError => e
    @logger.fatal('generic I/O exception, exiting..')
    @logger.debug("the exception was: #{e}")
    @logger.debug("and the backtrace was: #{e.backtrace.inspect}")
    exit1
  end

  def args_init
    commandline_args=ARGV
    @logger.info('parameters passed: ' + commandline_args.to_s)

    debug=false
    never_exit=false
    
    commandline_args.each do |arg|
      case arg
      when '-y'   #this option will make the script not to crash on errors/exceptions etc
        never_exit=true
        commandline_args.delete('-y')
      when '-d'   #if the first argument "word" is '-d' enable the hidden top secret debug mode
        debug=true
        commandline_args.delete('-d')
      when /^-t[0-9]{1,2}$/   #fixme -- not ready, will crash and burn if invoked
        options[:thread_count]=arg.tr('-t', '').to_i
        commandline_args.delete(arg)
      when /^-m[0-9]{1,2}$/   #fixme -- not ready, will crash and burn if invoked
        options[:minfree_workers]=arg.tr('-m', '').to_i
        commandline_args.delete(arg)
      end
    end
    
    @logger.debug("the never_exit flag is: #{never_exit}")
    @logger.debug("the debug mode is: #{debug}")

    return commandline_args, debug, never_exit
  end

  def get_valid_url (repo, options)
    return check_jenkins(check_syntax(repo, options), options)
  end

  def check_syntax (repo, options)
    case repo
    when /^job_url_identifier10.*/
      return repo.sub('job_url_identifier10', 'job_url_identifier5').sub('/', '_')
    when /^job_url_identifier9.*/
      return repo.sub('job_url_identifier9', 'job_url_identifier4').sub('/', '_')
    when /^job_url_identifier8.*/
      return repo.sub('job_url_identifier8', 'job_url_identifier3').sub('/', '_')
    when /^job_url_identifier7.*/
      return repo.sub('job_url_identifier7', 'job_url_identifier2').sub('/', '_')
    when /^job_url_identifier6.*/
      return repo.sub('job_url_identifier6', 'job_url_identifier1').sub('/', '_')
    else  #invalid region/repository ?
      unless options[:never_exit]
        @logger.fatal("#{repo} is not a name_of_business_component, exiting..")
        exit 1
      else
        @logger.debug("#{repo} is not a name_of_business_component repository, but we're running in debug mode, so it will be processed normally") if  options[:debug]
        return repo
      end
    end
  end

  def check_jenkins (job, options)
    begin
      options[:debug] ? resource = RestClient::Resource.new(options[:url]+'/job/job_pattern1' + job + 'job_function1/',
        options[:credentials][:username],options[:credentials][:password]) :
        resource = RestClient::Resource.new(options[:url] + '/job/job_pattern1' + job + 'job_function1/', 
        options[:credentials][:username],options[:credentials][:password])
    
      @logger.debug("the url used in check_jenkins is: #{resource.to_s}") if options[:debug]

      response=resource.post ''

      if response.code == 200          
        @logger.debug("job: #{job} has been found in jenkins..") if options[:debug]          
        return resource
      else
        @logger.error("job: #{job} doesn't seem to be set-up/exist in jenkins")
        options[:never_exit] ? (return false) : exit(1)
      end

    rescue RestClient::ResourceNotFound => e
      @logger.error("four oh four, the url provided (#{options[:url]}) is wrong or feed #{job} hasn't been imported in jenkins")
      @logger.debug("the resource url used was: #{resource.url} and the options were: #{resource.options}")
      unless options[:never_exit] == true
        exit 1
      else
        return false
      end
    rescue RestClient::ServiceUnavailable => e
      @logger.error("five oh three, the job #{job} is likely disabled?")
      @logger.debug("the resource url used was: #{resource.url} and the options were: #{resource.options}")
      unless options[:never_exit] == true
        exit 1
      else
        return false
      end
    rescue RestClient::InternalServerError => e
      @logger.error("got an error 500 while attempting to verify job #{job}, here\'s the exception:\n #{e}")
      @logger.debug("the resource url used was: #{resource.url} and the options were: #{resource.options}")
      unless options[:never_exit] == true
        exit 1
      else
        return false
      end
    rescue Errno::ECONNREFUSED => e
      @logger.error("got a connection refused while attempting to verify job #{job}")
      @logger.error("are you sure that the jenkins url is correct and jenkins is up and running?:\n #{e}")
      @logger.debug("the resource url used was: #{resource.url} and the options were: #{resource.options}")
      unless options[:never_exit] == true
        exit 1
      else
        return false
      end
    rescue Exception => e
      @logger.error("bumped into a generic exception while attempting to verify job #{job}:\n #{e}")
      puts "the resource url used was: #{resource.url} and the options were: #{resource.options}"
      unless options[:never_exit] == true
        exit 1
      else
        return false
      end
    end #fixme (more cases covered, email errors to me)
  end

  def process_name_of_business_component(url, options)
    name_of_business_component=RestClient::Resource.new(url, options[:credentials][:username],options[:credentials][:password])
    (result=trigger_build(name_of_business_component)) ? getjob_function2status(result, options) :
      @logger.warn("the build job for #{name_of_business_component} has been running for more than 20 minutes, the script will move"\
        "on to the next job now, please check the status in sonar manually, in 20 minutes") #fixme
  rescue RestClient::InternalServerError => e
    @logger.error("the attempt to build #{url.to_s.sub(/^.*job_pattern1/, '').sub(/job_function1.*$/, '')} completed. Result was FAILURE")
    @logger.error("we got an error 500 (check if the job is disabled?)")      
    @logger.debug("the exception was: " + e.to_s)
    @logger.debug("and the backtrace: #{e.backtrace.inspect.to_s}")
    if options[:never_exit] == true
      return "the build of " + url.to_s.sub(/^.*job_pattern1/, '').sub(/job_function1.*$/, '') + " failed, "\
        "we got an error 500 from jenkins,"\
        "this probably means that the job is disabled?"
    else
      exit 1
    end
  end

  def trigger_build(object)
    resource = RestClient::Resource.new(object.url+'build', object.options)
    response = resource.post ""

    if response.code == 201 #fixme throw exception
      queue_url = response.headers[:location]

      (1..1200).each do #check once every sec. for 20 mins
        if (result=isjob_function2complete?(queue_url, resource.options))
          #fixme no results? something went wrong, handle url exceptions etc
          return result.to_s
        end
        sleep 1
      end

      return false
    else
      #fixme handle non 201 error codes
    end
  end

  def isjob_function2complete? (queue_url, options)    #fixme, change method name, actually checks if a job is still queued, not if it has completed.

    (0..80).each do #check every 15 seconds for 20 mins, if the child job has finished
      resource=RestClient::Resource.new(queue_url+'api/xml', options)
      response=resource.get

      if response && response.body.to_s != "" #fixme -- checking simply if we got something back != good enough
        response=resource.get
        if (job_url = Nokogiri::XML(response.body).xpath('/leftItem/executable/url/text()').to_s) != ""   #fixme, will return true if the job has been picked up from the queue, not if it was (successfully) completed
          resource = RestClient::Resource.new(job_url + 'api/xml', options)
          response = resource.get
          if Nokogiri::XML(response.body).xpath('/freeStyleBuild/building/text()').to_s == "false"
            return job_url.to_s
          end
        end        #fixme -- what if that xpath never works?
      end
      sleep 15
    end

    return false
  end

  def getjob_function2status(url, options)
    resource=RestClient::Resource.new(url+'api/xml', options[:credentials][:username],options[:credentials][:password])
    response=resource.get

    if response && response.body != ""   #fixme -- any body simply won't do
      case Nokogiri::XML(response.body).xpath('/freeStyleBuild/result/text()').to_s
      when 'SUCCESS'
        return "the build of #{url.to_s.sub(/^.*job_pattern1/, '').sub(/job_function1.*$/, '')} was successful"
      when 'FAILURE'
        return getjob_function2failures(url, options)
      when 'UNSTABLE'
        return getjob_function2failures(url, options)
      else
        @logger.error("unknown status returned from #{url}/api/xml") 
        options[:never_exit] ? (return false) : (@logger.fatal("exiting") ; exit(1))
        #fixme -- handle getting nothing back in a better way
      end
    end
  end

  def getjob_function2failures (url, options)  #fixme -- to return text only if there were build errors
    marked_bad=false

    resource = RestClient::Resource.new(url + 'logText/progressiveText?start=0', 
      options[:credentials][:username],options[:credentials][:password])
    build_output=resource.get
    comp_errors=[]

    build_output.split("\n").each do |line|
      if line=~/^job_pattern1.*job_function2.*completed. Result was FAILURE/
        marked_bad=true

        if line=~/.*_architecture2.*/
          comp_errors <<  "\n\t" 'The architecture2 compilation failed:'
          resource=RestClient::Resource.new(url.to_s.sub(/job_function1.*$/, 'job_function2architecture2/') + 'lastBuild/consoleText', 
            options[:credentials][:username],options[:credentials][:password])  #fixme -- we assume that the build job will adhere/match with the naming convention used for the poll job
          comp_errors.concat(find_comp_errors(resource.get, options)) #fixme -- what if we get an exception (resource not found/404 etc)?
        elsif line =~ /.*_architecture1.*/
          comp_errors << "\n\t" 'The architecture1 compilation failed:'
          resource=RestClient::Resource.new(url.to_s.sub(/job_function1.*$/, 'job_function2architecture1/') + 'lastBuild/consoleText', 
            options[:credentials][:username],options[:credentials][:password])  #fixme -- what if we get an exception (resource not found/404 etc)?
          comp_errors.concat(find_comp_errors(resource.get, options))
        else
          #fixme -- a build broke but it's not architecture2 or architecture1? throw?
        end
      end
    end

    if marked_bad == false
      return "The build of #{name_of_business_component=url.to_s.sub(/^.*job_pattern1/, '').sub(/job_function1.*$/, '')} was successful"
    else
      return comp_errors.insert(0, "The build of #{name_of_business_component=url.to_s.sub(/^.*job_pattern1/, '').sub(/job_function1.*$/, '')} failed, build logs follow:").join("\n")
    end
  end

  def find_comp_errors(build_failures, options)
    exclusions = [ '-errwarn',
      'Entering directory',
      '[workspace]',
      'Building in workspace',
      '[EnvInject]',
      '/u01/toolkit',
      'Started by user',
      'SUNWspro/bin/CC',
      'Started by upstream project',
      'originally caused by:',
      'Started by an SCM change',
      'jenkins_toolkit',
      '/usr/bin/gcc',
      '/fubsy_version.sh',
      'Build step \'Execute shell\' marked build as',
      'Finished: ',
      'Warning: you have no plugins providing access control for builds',
      'Triggering a new build of ',
      'Leaving directory `/bb/data2/',
      '-march=i686']

    #todo - limit the compilation output returned to the user..
    
    errors=build_failures.split("\n")
    @logger.debug("error logs before processing: #{errors}") if options[:debug]
    exclusions.each do |exclusion|
      errors.delete_if {|element| element.include?(exclusion)}
    end
    @logger.debug("error logs after processing: #{errors}") if options[:debug]
    return errors
  end
  
  def compact_results(queue)
    return lambda do
      message=[]
      (1..queue.length).each do
        message << queue.pop
      end
      message.map{|el| el+"\n"}.reduce(:+)
    end
  end
  
  def handle_results (results_q, successful_builds, unsuccessful_builds)
    if results_q.length > 0
      
      build_results=compact_results(results_q)
      success_results=compact_results(successful_builds)
      failure_results=compact_results(unsuccessful_builds)

      @logger.info("the build(s) completed, the results are: \n" + build_results.call)
       
      if successful_builds.length > 0
        @logger.info("successful builds summary:\n" + success_results.call)
      else
        @logger.info("there weren't any successful builds")
      end

      if unsuccessful_builds.length > 0
        @logger.info("unsuccessful builds summary:\n" + failure_results.call)
      else
        @logger.info("there weren't any unsuccessful builds")
      end
    else
      @logger.error("\nthe results queue is empty.. something went horribly wrong.. :(")
    end
  end

  def get_total_executors(options)
    request = RestClient::Resource.new(options[:url]+'/computer/api/xml', options[:credentials][:username],options[:credentials][:password])
    (total_executors = Nokogiri::XML(request.get.body).xpath('computerSet/totalExecutors/text()').to_s) != "" ?
      total_executors.to_i : nil 
  end

  def get_busy_executors(options)
    request = RestClient::Resource.new(options[:url]+'/computer/api/xml', options[:credentials][:username],options[:credentials][:password])
    (busy_executors = Nokogiri::XML(request.get.body).xpath('computerSet/busyExecutors/text()').to_s) != "" ?
      busy_executors.to_i : nil 
  end

  class WorkerPool
    attr_reader :thread_arr
  
    def initialize(logger, thread_num, repo_q, results_q, successful_builds, unsuccessful_builds, options)
      @thread_arr=Array.new(thread_num)
      @logger=logger
      @logger.debug("spawning #{thread_num} thread(s) to process #{repo_q.length} repositories")

      for thread_num in (0..@thread_arr.length - 1) do
        @thread_arr[thread_num]=Thread.new(@logger, repo_q, results_q, successful_builds, unsuccessful_builds, options) do
          while true do
            start_time=Time.now
            repo=repo_q.pop
            @logger.info("processing job: " + repo.url.to_s)
            (result=process_name_of_business_component(repo.url, options)) =~ /^the build of.*was successful$/ ? successful_builds.push(repo.url) :
              unsuccessful_builds.push(repo.url)
            results_q.push(result)
            result ? @logger.debug("thread #{Thread.current}, has processed #{repo} in #{Time.now - start_time} seconds:\n" + result) :
              @logger.error("processing of name_of_business_component #{repo.url} returned null :(")
            sleep 1
          end
        end
      end  
    end
  
    def close
      @thread_arr.each do |thread|
        thread.join 10
      end
    end
  end

  class Scheduler 
    include TriggerMultipleJenkinsJobs
  
    attr_reader :successful_builds, :unsuccessful_builds, :repo_q, :results_q
  
    def initialize(logger, options, repo_list)
      @logger=logger
      repos_2_process, @successful_builds, @unsuccessful_builds, @repo_q, @results_q = init_queues(repo_list, options)
    
      if options[:minfree_workers] > 0 
        total_executors = get_total_executors(options)
        options[:minfree_workers] > total_executors ? (@logger.fatal("the number of minimum free workers is greater than"\
              "the number of total executors, exiting..");exit 1) : minfree_scheduler(repos_2_process, options)
      else
        free_scheduler(repos_2_process, options)
      end    
    end
  
    def init_queues(repo_list, options)
      repos_2_process=[]
      successful_builds=Queue.new
      unsuccessful_builds=Queue.new
      repo_q=Queue.new
      results_q=Queue.new

      valid_repos = lambda do
        valid_repos=[]
        repo_list.each do |repo|
          (valid_url=get_valid_url(repo,options)) ? valid_repos << valid_url : next
        end
        valid_repos
      end

      valid_repos.call.each do |repo|
        repos_2_process << repo
      end
  
      return repos_2_process, successful_builds, unsuccessful_builds, repo_q, results_q
    end
  
    def minfree_scheduler(repos_2_process, options)
      total_executors=get_total_executors(options)
      thread_num = total_executors - options[:minfree_workers]
      @pool=WorkerPool.new(@logger, thread_num, @repo_q, @results_q, @successful_builds, @unsuccessful_builds, options)
      
      repos_2_process.each do |repo|
        loop do 
          (total_executors - options[:minfree_workers] - get_busy_executors(options)) > 0 ? (repo_q.push(repo);sleep 5;break) : (sleep 1) #fixme -- catch exceptions
        end
      end
    end

    def free_scheduler(repos_2_process, options)
      thread_num = options[:thread_count]
      repos_2_process.each do |repo|
        repo_q.push(repo)
      end
      @pool=WorkerPool.new(@logger, thread_num, @repo_q, @results_q, @successful_builds, @unsuccessful_builds, options)
    end
  
    def thread_arr
      @pool.thread_arr
    end
  
    def close
      @pool.close
    end
  end

  def run
    @logger=LogDelegator.new

    options, repo_list = init

    if repo_list.length == 0
      @logger.fatal("the list of repos provided is empty: #{repo_list.to_s}, nothing to do here.. Exiting..")
      exit 0
    end

    scheduler=Scheduler.new(@logger, options, repo_list)

    while true
      @logger.debug("repo_q.empty?: " + scheduler.repo_q.empty?.to_s + " repo_q.num_waiting: " + scheduler.repo_q.num_waiting.to_s + 
          " thread_arr: " + scheduler.thread_arr.to_s + 
          " results_q.empty?: " + scheduler.results_q.empty?.to_s + 
          " results_q.num_waiting: " + scheduler.results_q.num_waiting.to_s) if options[:debug]
      
      break if scheduler.thread_arr.reduce { |all_asleep, thread| thread.stop? ? all_asleep = all_asleep && true : all_asleep = all_asleep && false} &&
        scheduler.repo_q.empty? &&
        scheduler.results_q.num_waiting == 0
      sleep 1
    end
    
    scheduler.close
    handle_results(scheduler.results_q, scheduler.successful_builds, scheduler.unsuccessful_builds)

  ensure
    @logger.debug("adieu.. run finished @#{Time.now}")
    @logger.close
  end
end

include TriggerMultipleJenkinsJobs
TriggerMultipleJenkinsJobs::run

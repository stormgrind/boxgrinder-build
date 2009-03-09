require 'jboss-cloud/exec'
require 'jboss-cloud/config'
require 'jboss-cloud-wizard/step_appliance'
require 'jboss-cloud-wizard/step_disk'
require 'jboss-cloud-wizard/step_memory'
require 'jboss-cloud-wizard/step_output_format'
require 'yaml'
require 'fileutils'

module JBossCloudWizard
  class Wizard
    
    AVAILABLE_OUTPUT_FORMATS = ["RAW",  "VMware Enterprise (ESX/ESXi)", "VMware Personal (Player, Workstation, Server)"]
    AVAILABLE_ARCHES = [ "i386", "x86_64" ]
    
    def initialize(options)
      @options     = options
      @appliances  = Array.new
      @configs     = Hash.new
      @dir_config  = ENV['JBOSS_CLOUD_CONFIG_DIR'] || "#{ENV['HOME']}/.jboss-cloud/configs"
      @dir_logs    = ENV['JBOSS_CLOUD_LOGS_DIR']   || "#{ENV['HOME']}/.jboss-cloud/logs"
      
      if !File.exists?(@dir_config) && !File.directory?(@dir_config)
        puts "Config dir doesn't exists. Creating new." if @options.verbose
        FileUtils.mkdir_p @dir_config
      end     
    end
    
    def read_available_appliances
      @appliances.clear
      
      puts "\nReading available appliances..." if @options.verbose
      
      Dir[ "#{@options.dir_appliances}/*/*.appl" ].each do |appliance_def|
        @appliances.push( File.basename( appliance_def, '.appl' ))
      end
      
      puts "No appliances found" if @options.verbose and @appliances.size == 0
      puts "Found #{@appliances.size} #{@appliances.size > 1 ? "appliances" : "appliance"} (#{@appliances.join(", ")})" if @options.verbose and @appliances.size > 0
    end
    
    def read_configs
      @configs.clear
      
      puts "\nReading saved configurations..." if @options.verbose
      
      Dir[ "#{@dir_config}/*.cfg" ].each do |config_def|
        config_name = File.basename( config_def, '.cfg' )
        
        @configs.store( config_name, YAML.load_file( config_def ))
      end
      
      puts "No saved configs found" if @options.verbose and @configs.size == 0
      puts "Found #{@configs.size} saved #{@configs.size > 1 ? "configs" : "config"} (#{@configs.keys.join(", ")})" if @options.verbose and @configs.size > 0
    end
    
    def display_configs
      return if @configs.size == 0
      
      puts "\n### Available configs:\r\n\r\n"
      
      i = 0
      
      @configs.keys.sort.each do |config|
        puts "    #{i+=1}. #{config}"
      end
      
      puts
    end
    
    def select_config
      print "### Select saved config or press ENTER to run wizard (1-#{@configs.size}) "
      
      config = gets.chomp
      return if config.length == 0 # enter pressed, no config selected, run wizard
      select_config unless valid_config?(config)
      
      @configs.keys.sort[config.to_i - 1]
    end
    
    def valid_config?(config)
      return false if config.to_i == 0
      return false unless config.to_i >= 1 and config.to_i <= @configs.size
      return true
    end
    
    def manage_configs
      display_configs
      
      return if @configs.size == 0
      return if (config = select_config) == nil
      
      stop = false
      
      until stop
        
        case ask_config_manage(config)
          when "v"
          display_config(@configs[config])
          
          pause
          when "d"
          delete_config(config)
          stop = true
          when "u"
          @config = @configs[config]
          stop = true
        end
        
      end
      
    end
    
    def delete_config(config)
      
      config_file = "#{@dir_config}/#{config}.cfg"
      
      unless File.exists?(config_file)
        puts "    Config file doesn't exists!"
        return
      end
      
      print "\n### You are going to delete config '#{config}'. Are you sure? [Y/n] "
      answer = gets.chomp
      
      delete_config(config) unless answer.downcase == "y" or answer.downcase == "n" or answer.length == 0
      
      if (answer.length == 0 or answer.downcase == "y")
        FileUtils.rm_f(config_file)
      end
      
      puts "\n    Configuration #{config} deleted"
      
      pause
      
      start
      abort
    end
    
    def pause
      print "\n### Press ENTER to continue... "
      gets
    end
    
    def ask_config_manage(config)
      puts "\n    You have selected config '#{config}'\r\n\r\n"
      
      print "### What do you want to do? ([v]iew, [d]elete, [u]se) [u] "
      answer = gets.chomp
      
      answer = "u" if answer.length == 0
      
      ask_config_manage(config) unless valid_config_manage_answer?(answer)
      answer
    end
    
    def valid_config_manage_answer?(answer)
      return true if answer.downcase == "d" or answer.downcase == "u" or answer.downcase == "v"
      return false
    end
    
    def init
      puts "\n###\r\n### Welcome to appliance builder wizard for #{@options.name}\r\n###"
      self
    end
    
    def ask_for_configuration_name
      print "\n### Please enter name for this configuration: "
      
      name = gets.chomp
      ask_for_configuration_name unless valid_configuration_name?(name)
      name
    end
    
    def save_config
      display_config(@config)
      
      print "\n### Do you want to save this configuration? [y/N] "
      answer = gets.chomp
      answer = "n" if answer.length == 0
      
      return unless answer == "y"
      
      name = ask_for_configuration_name
      
      filename = "#{@dir_config}/#{name}.cfg"
      
      if (File.exists?(filename))
        print "\n### Configuration #{name} already exists. Overwrite? [Y/n] "
        
        answer = gets.chomp
        answer = "y" if answer.length == 0
        
        unless answer.downcase == "y"
          save_config
          return
        end
      end
      
      File.new(filename, "w+").puts( @config.to_yaml )
      
      puts "\n    Configuration #{name} saved"
    end
    
    def valid_configuration_name?(name)
      return false if name.length == 0
      return true unless name.match(/^\w+$/) == nil
      return false
    end
    
    def start
      
      #system("clear")
      @config = nil
      
      read_available_appliances
      
      if @appliances.size == 0
        puts "\n    No appliance definitions found, aborting.\r\n\r\n"
        abort
      end
      
      read_configs
      manage_configs unless @configs.size == 0
      
      if (@config == nil)
        @config = StepAppliance.new(@appliances, AVAILABLE_ARCHES).start
        @config = StepDisk.new(@config).start
        @config = StepMemory.new(@config).start
        @config = StepOutputFormat.new(@config, AVAILABLE_OUTPUT_FORMATS).start
        
        save_config
      end
      
      build
    end
    
    protected
    
    
    def display_config(config)
      puts "\n### Selected options:\r\n"
      
      puts "\n    Appliance:\t\t#{config.name}"
      puts "    Memory:\t\t#{config.mem_size}MB"
      puts "    Network:\t\t#{config.network_name}" if (config.output_format.to_i == 2 or config.output_format.to_i == 3)
      puts "    Disk:\t\t#{config.disk_size}GB"
      puts "    Output format:\t#{AVAILABLE_OUTPUT_FORMATS[config.output_format.to_i-1]}"
      
    end
    
    def is_correct?
      print "\nIs this correct? [Y/n] "
      
      correct_answer = gets.chomp
      
      return true if correct_answer.length == 0
      return is_correct? unless (correct_answer.length == 1)
      return is_correct? if (correct_answer.upcase != "Y" and correct_answer.upcase != "N")
      
      if (correct_answer.upcase == "Y")
        return true
      else
        return false
      end
    end
    
    def build
      
      build_time = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
      log_file_name = "#{@dir_logs}/wizard_#{build_time}"
      
      puts "\n    Building #{@appliance}... (this may take a while)"
      #puts "\n    Wizard runs in quiet mode, messages are not shown. Please check '#{log_file_name}' for logs.\r\n\r\n" unless @options.verbose
      
      command = "JBOSS_CLOUD_DISK_SIZE=\"#{@config.disk_size}\" JBOSS_CLOUD_NETWORK_NAME=\"#{@config.network_name}\" JBOSS_CLOUD_ARCH=\"#{@config.arch}\" JBOSS_CLOUD_OS_NAME=\"#{@config.os_name}\" JBOSS_CLOUD_OS_VERSION=\"#{@config.os_version}\" JBOSS_CLOUD_VCPU=\"#{@config.vcpu}\" JBOSS_CLOUD_MEM_SIZE=\"#{@config.mem_size}\" "
      
      command += "rake appliance:#{@config.name}" if @config.output_format.to_i == 1
      command += "rake appliance:#{@config.name}:vmware:enterprise" if @config.output_format.to_i == 2
      command += "rake appliance:#{@config.name}:vmware:personal" if @config.output_format.to_i == 3
      
      unless execute( "#{command}", @options.verbose, log_file_name )
        puts "\n    Build failed. Check log file: '#{log_file_name}'"
        exit(1)
      end
      
      puts "\n    Build was successful. Check '#{Dir.pwd}/build/appliances/#{@config.arch}/#{@config.name}/' folder for output files."
    end
    
  end
end

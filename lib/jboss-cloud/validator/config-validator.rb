# JBoss, Home of Professional Open Source
# Copyright 2009, Red Hat Middleware LLC, and individual contributors
# by the @authors tag. See the copyright.txt in the distribution for a
# full listing of individual contributors.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'jboss-cloud/config'
require 'jboss-cloud/validator/errors'

module JBossCloud
  class ConfigValidator
    def validate( config )
      @config = config
      
      validate_base_pkgs
      validate_vmware_files
      validate_appliance_dir
    end
    
    def validate_base_pkgs
      base_pkgs_suffix = "#{@config.os_name}/#{@config.os_version}/base-pkgs.ks"
      
      if File.exists?( "#{@config.dir.kickstarts}/#{base_pkgs_suffix}" )
        @config.files.base_pkgs = base_pkgs
      else
        @config.files.base_pkgs = "#{@config.dir.base}/kickstarts/#{base_pkgs_suffix}"
      end
      
      raise ValidationError, "base-pkgs.ks file doesn't exists for your OS (#{@config.os_name} #{@config.os_version})" unless File.exists?( @config.files.base_pkgs )
    end
    
    def validate_appliance_dir
      raise ValidationError, "Appliances directory '#{@config.dir.appliances}' doesn't exists, please create one or adjust your" if !File.exists?(File.dirname( @config.dir.appliances )) && !File.directory?(File.dirname( @config.dir.appliances ))
      raise ValidationError, "There are no appliances to build in appliances directory '#{@config.dir.appliances}'" if Dir[ "#{@config.dir.appliances}/*/*.appl" ].size == 0
    end
    
    
    
    def validate_vmware_files
      if File.exists?( "#{@config.dir.src}/base.vmdk" )
        @config.files.base_vmdk = "#{@config.dir.src}/base.vmdk"
      else
        @config.files.base_vmdk = "#{@config.dir.base}/src/base.vmdk"
      end
      
      raise ValidationError, "base.vmdk file doesn't exists, please check you configuration)" unless File.exists?( @config.files.base_vmdk )      
      
      if File.exists?( "#{@config.dir.src}/base.vmx" )
        @config.files.base_vmx = "#{@config.dir.src}/base.vmx"
      else
        @config.files.base_vmx = "#{@config.dir.base}/src/base.vmx"
      end
      
      raise ValidationError, "base.vmx file doesn't exists, please check you configuration)" unless File.exists?( @config.files.base_vmx )
    end
    
    
  end
end

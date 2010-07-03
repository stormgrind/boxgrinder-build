require 'boxgrinder-build/helpers/plugin-helper'
require 'rspec-helpers/rspec-config-helper'
require 'ostruct'

module BoxGrinder
  describe PluginHelper do
    include RSpecConfigHelper

    before(:all) do
      @current_arch = (-1.size) == 8 ? "x86_64" : "i386"
    end

    before(:each) do
      @plugin_helper = PluginHelper.new( :options => OpenStruct.new )
    end

    it "should parse plugin list and return nil when no plugins are provided" do
      @plugin_helper.parse_plugin_list.should == nil
    end

    it "should parse plugin list with double quotes" do
      @plugin_helper = PluginHelper.new( :options => OpenStruct.new( :plugins => '"abc,def"' ) )
      @plugin_helper.parse_plugin_list.should == ['abc', 'def']
    end

    it "should parse plugin list with single quotes" do
      @plugin_helper = PluginHelper.new( :options => OpenStruct.new( :plugins => "'abc,def'" ) )
      @plugin_helper.parse_plugin_list.should == ['abc', 'def']
    end

    it "should parse plugin list with single quotes and clean up it" do
      @plugin_helper = PluginHelper.new( :options => OpenStruct.new( :plugins => "'    abc ,    def'" ) )
      @plugin_helper.parse_plugin_list.should == ['abc', 'def']
    end

    it "should require default plugins" do
      plugins = %w(boxgrinder-build-fedora-os-plugin boxgrinder-build-rhel-os-plugin boxgrinder-build-centos-os-plugin boxgrinder-build-ec2-platform-plugin)

      plugins.each do |plugin|
        @plugin_helper.should_receive(:gem).ordered.with(plugin)
        @plugin_helper.should_receive(:require).once.with(plugin)
      end

      @plugin_helper.read_and_require
    end

    it "should read plugins specified in command line" do
      @plugin_helper = PluginHelper.new( :options => OpenStruct.new( :plugins => 'abc,def' ) )

      @plugin_helper.should_receive(:gem).ordered.with('abc')
      @plugin_helper.should_receive(:require).ordered.with('abc')
      @plugin_helper.should_receive(:gem).ordered.with('def')
      @plugin_helper.should_receive(:require).ordered.with('def')

      @plugin_helper.read_and_require
    end
  end
end

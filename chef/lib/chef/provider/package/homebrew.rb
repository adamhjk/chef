#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2010 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/provider/package'
require 'chef/mixin/command'
require 'chef/resource/package'

class Chef
  class Provider
    class Package
      class Homebrew < Chef::Provider::Package  
      
        def load_current_resource
          @current_resource = Chef::Resource::Package.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)
       
          Chef::Log.debug("Checking brew Cellar for #{@new_resource.package_name}")
          has_real_version = false
          status = popen4("brew info #{@new_resource.package_name}") do |pid, stdin, stdout, stderr|
            stdout.each do |line|
              case line
              when /^#{@new_resource.package_name} (.+)$/
                @candidate_version = $1
              when /\/Cellar\/#{@new_resource.package_name}\/(.+) \(.+\)/
                @current_resource.version = $1 unless has_real_version
              when /\/Cellar\/#{@new_resource.package_name}\/(.+) \(.+\) *$/
                @current_resource.version = $1
                has_real_version = true 
              when /^Not installed$/
                @current_resource.version = nil
              end
            end
          end

          unless status.exitstatus == 0
            raise Chef::Exceptions::Package, "brew info failed - #{status.inspect}!"
          end
        
          @current_resource
        end
     
        # if Chef::Config[:noop] == true ... 
        def install_package(name, version)
          run_command_with_systems_locale(
            :command => "brew install #{name} #{expand_options(@new_resource.options)}"
          )
        end
      
        def upgrade_package(name, version)
          install_package(name, version)
        end
      
        def remove_package(name, version)
          run_command_with_systems_locale(
            :command => "brew remove #{name}"
          )
        end
      
      end
    end
  end
end

